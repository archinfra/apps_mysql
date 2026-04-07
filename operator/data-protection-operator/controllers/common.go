package controllers

import (
	"strings"
	"time"

	apimeta "k8s.io/apimachinery/pkg/api/meta"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	ctrl "sigs.k8s.io/controller-runtime"

	dpv1alpha1 "github.com/archinfra/apps_mysql/operator/data-protection-operator/api/v1alpha1"
)

func nowTime() *metav1.Time {
	t := metav1.NewTime(time.Now().UTC())
	return &t
}

func markCondition(conditions *[]metav1.Condition, conditionType string, status metav1.ConditionStatus, reason, message string, generation int64) {
	apimeta.SetStatusCondition(conditions, metav1.Condition{
		Type:               conditionType,
		Status:             status,
		Reason:             reason,
		Message:            message,
		ObservedGeneration: generation,
		LastTransitionTime: metav1.Now(),
	})
}

func phaseMessage(phase dpv1alpha1.ResourcePhase) string {
	switch phase {
	case dpv1alpha1.ResourcePhaseReady:
		return "resource is accepted by the scaffold controller"
	case dpv1alpha1.ResourcePhaseRunning:
		return "resource has been accepted and is awaiting execution wiring"
	case dpv1alpha1.ResourcePhaseSucceeded:
		return "request completed in the scaffold controller"
	case dpv1alpha1.ResourcePhaseFailed:
		return "resource failed validation"
	case dpv1alpha1.ResourcePhasePaused:
		return "resource is suspended"
	default:
		return "resource is pending reconciliation"
	}
}

func sanitizeName(value string) string {
	value = strings.ToLower(strings.TrimSpace(value))
	value = strings.ReplaceAll(value, "_", "-")
	value = strings.ReplaceAll(value, ".", "-")
	value = strings.ReplaceAll(value, "/", "-")
	value = strings.ReplaceAll(value, " ", "-")
	return value
}

func requeueSoon() ctrl.Result {
	return ctrl.Result{RequeueAfter: 30 * time.Second}
}
