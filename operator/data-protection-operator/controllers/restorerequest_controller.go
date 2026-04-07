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

type RestoreRequestReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

func (r *RestoreRequestReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	logger := log.FromContext(ctx).WithValues("restoreRequest", req.NamespacedName.String())

	var restore dpv1alpha1.RestoreRequest
	if err := r.Get(ctx, req.NamespacedName, &restore); err != nil {
		if apierrors.IsNotFound(err) {
			return ctrl.Result{}, nil
		}
		return ctrl.Result{}, err
	}

	original := restore.DeepCopy()
	restore.Status.ObservedGeneration = restore.Generation
	if restore.Status.StartedAt == nil {
		restore.Status.StartedAt = nowTime()
	}

	if err := restore.Spec.ValidateBasic(); err != nil {
		restore.Status.Phase = dpv1alpha1.ResourcePhaseFailed
		markCondition(&restore.Status.Conditions, "Accepted", metav1.ConditionFalse, "InvalidSpec", err.Error(), restore.Generation)
	} else {
		restore.Status.Phase = dpv1alpha1.ResourcePhaseRunning
		restore.Status.JobName = sanitizeName(restore.Name) + "-restore"
		markCondition(&restore.Status.Conditions, "Accepted", metav1.ConditionTrue, "Scaffolded", "restore request accepted; execution job wiring is the next milestone", restore.Generation)
	}

	if err := r.Status().Patch(ctx, &restore, client.MergeFrom(original)); err != nil {
		logger.Error(err, "unable to patch RestoreRequest status")
		return ctrl.Result{}, err
	}

	return ctrl.Result{}, nil
}

func (r *RestoreRequestReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&dpv1alpha1.RestoreRequest{}).
		Complete(r)
}
