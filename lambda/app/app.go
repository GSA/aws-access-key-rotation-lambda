// Package app provides the underlying functionality for the grace-ansible-lambda
package app

import (
	"context"
	"fmt"
	"strings"

	"github.com/GSA/ciss-utils/aws/sm"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/iam"
	"github.com/aws/aws-sdk-go-v2/service/kms"
	"github.com/aws/aws-sdk-go-v2/service/secretsmanager"
	smt "github.com/aws/aws-sdk-go-v2/service/secretsmanager/types"
	env "github.com/caarlos0/env/v6"
)

// Settings holds all variables read from the ENV
type Settings struct {
	Prefix      string   `env:"PREFIX" envDefault:"key-"`
	Usernames   []string `env:"USERNAMES"`
	KmsKeyAlias string   `env:"KMS_KEY_ALIAS"`
	Region      string   `env:"REGION" envDefault:"us-east-1"`
}

// App is a wrapper for running Lambda
type App struct {
	settings *Settings
	cfg      aws.Config
	secrets  []*sm.Secret
	KmsKeyID string
}

// New creates a new App
func New() (*App, error) {
	s := Settings{}
	a := &App{
		settings: &s,
	}
	err := env.Parse(&s)
	if err != nil {
		return nil, fmt.Errorf("failed to parse ENV: %v", err)
	}
	return a, nil
}

// Run executes the lambda functionality
func (a *App) Run() error {
	var err error
	a.cfg, err = config.LoadDefaultConfig(context.TODO(),
		config.WithRegion(a.cfg.Region),
	)
	if err != nil {
		return fmt.Errorf("error connecting to AWS: %v", err)
	}

	// validate all provided usernames exist
	err = a.resolveUsers()
	if err != nil {
		return err
	}

	// create a new access key and delete the oldest key for all valid users
	err = a.updateKeys()
	if err != nil {
		return err
	}

	// resolve kms key alias to the key id
	err = a.resolveKeyID()
	if err != nil {
		return err
	}

	// resolve all existing secret ids in secrets manager
	err = a.resolveKeys()
	if err != nil {
		return err
	}

	// update or create secrets in secrets manager for all access keys
	err = a.storeKeys()
	if err != nil {
		return err
	}

	return nil
}

func (a *App) updateKeys() error {
	for _, s := range a.secrets {
		err := a.cleanupOldKey(s)
		if err != nil {
			return fmt.Errorf("failed to cleanup old key: %v", err)
		}

		err = a.createNewKey(s)
		if err != nil {
			return fmt.Errorf("failed to create new key: %v", err)
		}
	}

	return nil
}

func (a *App) resolveKeys() error {
	allSecrets, err := a.getSecrets()
	if err != nil {
		return fmt.Errorf("failed to list all secrets: %v", err)
	}
	// set the desired secret name and secret ID if one already exists
	for _, s := range a.secrets {
		s.SecretName = fmt.Sprintf("%s-%s", a.settings.Prefix, s.Username)
		for _, entry := range allSecrets {
			if strings.EqualFold(s.SecretName, aws.ToString(entry.Name)) {
				s.SecretID = aws.ToString(entry.ARN)
			}
		}
	}
	return nil
}

func (a *App) getSecrets() ([]smt.SecretListEntry, error) {
	var allSecrets []smt.SecretListEntry

	svc := secretsmanager.NewFromConfig(a.cfg)
	input := &secretsmanager.ListSecretsInput{}
	p := secretsmanager.NewListSecretsPaginator(svc, input)

	for p.HasMorePages() {
		output, err := p.NextPage(context.TODO())
		if err != nil {
			return nil, fmt.Errorf("failed to list secrets: %v", err)
		}
		allSecrets = append(allSecrets, output.SecretList...)
	}

	return allSecrets, nil
}

func (a *App) storeKeys() error {
	for _, s := range a.secrets {
		err := a.storeKey(s)
		if err != nil {
			return fmt.Errorf("failed to store key: %v", err)
		}
	}
	return nil
}

func (a *App) storeKey(s *sm.Secret) error {
	svc := secretsmanager.NewFromConfig(a.cfg)

	secret, err := s.ToJSON()
	if err != nil {
		return err
	}

	if len(s.SecretID) == 0 {
		_, err := svc.CreateSecret(context.TODO(), &secretsmanager.CreateSecretInput{
			Name:         aws.String(s.SecretName),
			KmsKeyId:     aws.String(a.KmsKeyID),
			SecretString: aws.String(secret),
		})
		if err != nil {
			return fmt.Errorf("failed to create secret with name: %q -> %v", s.SecretName, err)
		}
		return nil
	}

	_, err = svc.UpdateSecret(context.TODO(), &secretsmanager.UpdateSecretInput{
		SecretId:     aws.String(s.SecretID),
		KmsKeyId:     aws.String(a.KmsKeyID),
		SecretString: aws.String(secret),
	})
	if err != nil {
		return fmt.Errorf("failed to update secret with name: %q -> %v", s.SecretName, err)
	}
	return nil
}

func (a *App) createNewKey(s *sm.Secret) error {
	svc := iam.NewFromConfig(a.cfg)
	output, err := svc.CreateAccessKey(context.TODO(), &iam.CreateAccessKeyInput{
		UserName: aws.String(s.Username),
	})
	if err != nil {
		return fmt.Errorf("failed to create access key for user %q -> %v", s.Username, err)
	}
	s.KeyID = aws.ToString(output.AccessKey.AccessKeyId)
	s.Type = "aws"
	s.Secret = fmt.Sprintf("%s:%s", aws.ToString(output.AccessKey.AccessKeyId), aws.ToString(output.AccessKey.SecretAccessKey))
	return nil
}

func (a *App) cleanupOldKey(s *sm.Secret) error {
	svc := iam.NewFromConfig(a.cfg)

	output, err := svc.ListAccessKeys(context.TODO(), &iam.ListAccessKeysInput{
		UserName: aws.String(s.Username),
	})
	if err != nil {
		return fmt.Errorf("failed to list access keys for user: %q -> %v", s.Username, err)
	}

	// if we have two keys we need to delete one of them
	// find the oldest of the two and delete it
	if len(output.AccessKeyMetadata) == 2 {
		a := aws.ToTime(output.AccessKeyMetadata[0].CreateDate)
		b := aws.ToTime(output.AccessKeyMetadata[1].CreateDate)

		oldest := output.AccessKeyMetadata[0]
		if a.After(b) {
			oldest = output.AccessKeyMetadata[1]
		}

		_, err := svc.DeleteAccessKey(context.TODO(), &iam.DeleteAccessKeyInput{
			AccessKeyId: oldest.AccessKeyId,
			UserName:    oldest.UserName,
		})
		if err != nil {
			return fmt.Errorf("failed to delete access key for user: %q -> %v", s.Username, err)
		}
	}

	return nil
}

func (a *App) resolveUsers() error {
	users, err := a.getAllUsers()
	if err != nil {
		return err
	}

	for _, name := range a.settings.Usernames {
		var found bool
		for _, u := range users {
			if strings.EqualFold(u, name) {
				a.secrets = append(a.secrets, &sm.Secret{
					Username: u,
				})
				found = true
			}
		}
		if !found {
			if len(a.settings.Usernames) == 1 {
				return fmt.Errorf("user with name %q does not exist in IAM", name)
			}
			// this should not be an error if we are processing multiple users
			fmt.Printf("user with name %q does not exist in IAM\n", name)
		}
	}

	return nil
}

func (a *App) getAllUsers() ([]string, error) {
	var allUsers []string

	svc := iam.NewFromConfig(a.cfg)
	input := &iam.ListUsersInput{}
	p := iam.NewListUsersPaginator(svc, input)

	for p.HasMorePages() {
		output, err := p.NextPage(context.TODO())
		if err != nil {
			return nil, fmt.Errorf("failed to enumerate IAM users: %v", err)
		}
		for _, u := range output.Users {
			allUsers = append(allUsers, aws.ToString(u.UserName))
		}
	}

	return allUsers, nil
}

func (a *App) resolveKeyID() error {
	keyID, err := a.getKmsKeyID(a.settings.KmsKeyAlias)
	if err != nil {
		return fmt.Errorf("failed to resolve Key ID: %v", err)
	}

	a.KmsKeyID = keyID

	return nil
}

func (a *App) getKmsKeyID(alias string) (string, error) {
	svc := kms.NewFromConfig(a.cfg)
	input := &kms.ListAliasesInput{}
	p := kms.NewListAliasesPaginator(svc, input)

	for p.HasMorePages() {
		output, err := p.NextPage(context.TODO())
		if err != nil {
			return "", fmt.Errorf("failed to enumerate kms key aliases: %v", err)
		}
		for _, entry := range output.Aliases {
			if strings.EqualFold(alias, aws.ToString(entry.AliasName)) {
				return aws.ToString(entry.TargetKeyId), nil
			}
		}
	}

	return "", fmt.Errorf("failed to locate kms key with alias: %s", alias)
}
