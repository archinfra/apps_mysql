package controllers

import (
	"context"
	"fmt"

	apierrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/log"

	dpv1alpha1 "github.com/archinfra/apps_mysql/operator/data-protection-operator/api/v1alpha1"
)

type BackupPolicyReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

func (r *BackupPolicyReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	logger := log.FromContext(ctx).WithValues("backupPolicy", req.NamespacedName.String())

	var policy dpv1alpha1.BackupPolicy
	if err := r.Get(ctx, req.NamespacedName, &policy); err != nil {
		if apierrors.IsNotFound(err) {
			return ctrl.Result{}, nil
		}
		return ctrl.Result{}, err
	}

	original := policy.DeepCopy()
	policy.Status.ObservedGeneration = policy.Generation
	policy.Status.CronJobNames = dpv1alpha1.PredictCronJobNames(policy.Name, policy.Spec.RepositoryRefs)

	if policy.Spec.Suspend || policy.Spec.Schedule.Suspend {
		policy.Status.Phase = dpv1alpha1.ResourcePhasePaused
		markCondition(&policy.Status.Conditions, "Ready", metav1.ConditionFalse, "Suspended", phaseMessage(policy.Status.Phase), policy.Generation)
	} else if err := policy.Spec.ValidateBasic(); err != nil {
		policy.Status.Phase = dpv1alpha1.ResourcePhaseFailed
		markCondition(&policy.Status.Conditions, "Ready", metav1.ConditionFalse, "InvalidSpec", err.Error(), policy.Generation)
	} else {
		policy.Status.Phase = dpv1alpha1.ResourcePhaseReady
		markCondition(&policy.Status.Conditions, "Ready", metav1.ConditionTrue, "Scaffolded", fmt.Sprintf("policy accepted; predicted cronjobs=%v", policy.Status.CronJobNames), policy.Generation)
	}

	if err := r.Status().Patch(ctx, &policy, client.MergeFrom(original)); err != nil {
		logger.Error(err, "unable to patch BackupPolicy status")
		return ctrl.Result{}, err
	}

	return ctrl.Result{}, nil
}

func (r *BackupPolicyReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&dpv1alpha1.BackupPolicy{}).
		Complete(r)
}
