package v1alpha1

import (
	"fmt"
	"sort"
	"strings"

	batchv1 "k8s.io/api/batch/v1"
	corev1 "k8s.io/api/core/v1"
)

func (s *BackupPolicySpec) ValidateBasic() error {
	if strings.TrimSpace(s.SourceRef.Name) == "" {
		return fmt.Errorf("spec.sourceRef.name is required")
	}

	if len(s.RepositoryRefs) == 0 {
		return fmt.Errorf("spec.repositoryRefs requires at least one repository")
	}

	if strings.TrimSpace(s.Schedule.Cron) == "" && !s.Suspend {
		return fmt.Errorf("spec.schedule.cron is required unless the policy is suspended")
	}

	return nil
}

func (s *BackupRunSpec) ValidateBasic() error {
	if strings.TrimSpace(s.SourceRef.Name) == "" {
		return fmt.Errorf("spec.sourceRef.name is required")
	}
	if len(s.RepositoryRefs) == 0 && s.PolicyRef == nil {
		return fmt.Errorf("spec.repositoryRefs or spec.policyRef is required")
	}
	return nil
}

func (s *RestoreRequestSpec) ValidateBasic() error {
	if strings.TrimSpace(s.SourceRef.Name) == "" {
		return fmt.Errorf("spec.sourceRef.name is required")
	}
	if s.BackupRunRef == nil && strings.TrimSpace(s.Snapshot) == "" {
		return fmt.Errorf("spec.backupRunRef or spec.snapshot is required")
	}
	return nil
}

func (s *BackupPolicySpec) EffectiveConcurrencyPolicy() batchv1.ConcurrencyPolicy {
	if strings.TrimSpace(string(s.Schedule.ConcurrencyPolicy)) == "" {
		return batchv1.ForbidConcurrent
	}
	return s.Schedule.ConcurrencyPolicy
}

func PredictCronJobNames(policyName string, repositoryRefs []corev1.LocalObjectReference) []string {
	names := make([]string, 0, len(repositoryRefs))
	for _, ref := range repositoryRefs {
		repoName := strings.TrimSpace(ref.Name)
		if repoName == "" {
			continue
		}
		names = append(names, fmt.Sprintf("%s-%s", sanitizeName(policyName), sanitizeName(repoName)))
	}
	sort.Strings(names)
	return names
}

func sanitizeName(value string) string {
	value = strings.ToLower(strings.TrimSpace(value))
	value = strings.ReplaceAll(value, "_", "-")
	value = strings.ReplaceAll(value, ".", "-")
	value = strings.ReplaceAll(value, "/", "-")
	value = strings.ReplaceAll(value, " ", "-")
	return value
}
