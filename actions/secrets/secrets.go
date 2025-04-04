package secrets

import (
	"encoding/base64"
	"encoding/json"
	"fmt"

	"github.com/rancher/shepherd/clients/rancher"
	namegen "github.com/rancher/shepherd/pkg/namegenerator"
	clusterapi "github.com/rancher/tests/actions/kubeapi/clusters"
	corev1 "k8s.io/api/core/v1"
)

const (
	SecretSteveType = "secret"
)

// CreateSecret is a helper to create a secret using wrangler client
func CreateSecret(client *rancher.Client, clusterID, namespaceName string, data map[string][]byte, secretType corev1.SecretType) (*corev1.Secret, error) {
	ctx, err := clusterapi.GetClusterWranglerContext(client, clusterID)
	if err != nil {
		return nil, fmt.Errorf("failed to get cluster context: %w", err)
	}

	secretName := namegen.AppendRandomString("testsecret")
	secretTemplate := NewSecretTemplate(secretName, namespaceName, data, secretType)

	createdSecret, err := ctx.Core.Secret().Create(&secretTemplate)
	if err != nil {
		return nil, fmt.Errorf("failed to create secret: %w", err)
	}

	return createdSecret, nil
}

// CreateSecretWithAnnotations is a helper to create a secret and includes provided annotations using wrangler client
func CreateSecretWithAnnotations(client *rancher.Client, clusterID, namespaceName string, data map[string][]byte, annotations map[string]string, secretType corev1.SecretType) (*corev1.Secret, error) {
	ctx, err := clusterapi.GetClusterWranglerContext(client, clusterID)
	if err != nil {
		return nil, fmt.Errorf("failed to get cluster context: %w", err)
	}

	secretName := namegen.AppendRandomString("testsecret")
	secretTemplate := NewSecretTemplateWithAnnotations(secretName, namespaceName, data, annotations, secretType)

	createdSecret, err := ctx.Core.Secret().Create(&secretTemplate)
	if err != nil {
		return nil, fmt.Errorf("failed to create secret: %w", err)
	}

	return createdSecret, nil
}

// UpdateSecretData is a helper to update the existing secret data with new  data
func UpdateSecretData(secret *corev1.Secret, newData map[string][]byte) *corev1.Secret {
	updatedSecretObj := secret.DeepCopy()
	if updatedSecretObj.Data == nil {
		updatedSecretObj.Data = make(map[string][]byte)
	}

	for key, value := range newData {
		updatedSecretObj.Data[key] = value
	}

	return updatedSecretObj
}

// CreateRegistrySecretDockerConfigJSON is a helper to generate dockerconfigjson content for a registry secret
func CreateRegistrySecretDockerConfigJSON(registryconfig *Config) (string, error) {
	registry := registryconfig.Name
	username := registryconfig.Username
	password := registryconfig.Password

	if username == "" || password == "" {
		return "", fmt.Errorf("missing registry credentials in the config file")
	}

	auth := map[string]interface{}{
		"username": username,
		"password": password,
		"auth":     base64.StdEncoding.EncodeToString([]byte(username + ":" + password)),
	}

	config := map[string]interface{}{
		"auths": map[string]interface{}{
			registry: auth,
		},
	}

	configJSON, err := json.Marshal(config)
	if err != nil {
		return "", err
	}

	return string(configJSON), nil
}
