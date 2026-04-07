package controllers

import (
	"context"

	apierrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/log"

	dpv1alpha1 "github.com/archinfra/apps_mysql/operator/data-protection-operator/api/v1alpha1"
)

type BackupRunReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

func (r *BackupRunReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	logger := log.FromContext(ctx).WithValues("backupRun", req.NamespacedName.String())

	var run dpv1alpha1.BackupRun
	if err := r.Get(ctx, req.NamespacedName, &run); err != nil {
		if apierrors.IsNotFound(err) {
			return ctrl.Result{}, nil
		}
		return ctrl.Result{}, err
	}

	original := run.DeepCopy()
	run.Status.ObservedGeneration = run.Generation
	if run.Status.StartedAt == nil {
		run.Status.StartedAt = nowTime()
	}

	if err := run.Spec.ValidateBasic(); err != nil {
		run.Status.Phase = dpv1alpha1.ResourcePhaseFailed
		markCondition(&run.Status.Conditions, "Accepted", metav1.ConditionFalse, "InvalidSpec", err.Error(), run.Generation)
	} else {
		run.Status.Phase = dpv1alpha1.ResourcePhaseRunning
		run.Status.JobNames = []string{sanitizeName(run.Name) + "-runner"}
		markCondition(&run.Status.Conditions, "Accepted", metav1.ConditionTrue, "Scaffolded", "backup run accepted; execution job wiring is the next milestone", run.Generation)
	}

	if err := r.Status().Patch(ctx, &run, client.MergeFrom(original)); err != nil {
		logger.Error(err, "unable to patch BackupRun status")
		return ctrl.Result{}, err
	}

	return ctrl.Result{}, nil
}

func (r *BackupRunReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&dpv1alpha1.BackupRun{}).
		Complete(r)
}
