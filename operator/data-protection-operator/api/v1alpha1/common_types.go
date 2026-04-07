package v1alpha1

import (
	batchv1 "k8s.io/api/batch/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

type BackupDriver string

const (
	BackupDriverMySQL    BackupDriver = "mysql"
	BackupDriverRedis    BackupDriver = "redis"
	BackupDriverMongoDB  BackupDriver = "mongodb"
	BackupDriverMinIO    BackupDriver = "minio"
	BackupDriverRabbitMQ BackupDriver = "rabbitmq"
	BackupDriverMilvus   BackupDriver = "milvus"
)

type RepositoryType string

const (
	RepositoryTypeNFS RepositoryType = "nfs"
	RepositoryTypeS3  RepositoryType = "s3"
)

type ResourcePhase string

const (
	ResourcePhasePending   ResourcePhase = "Pending"
	ResourcePhaseReady     ResourcePhase = "Ready"
	ResourcePhaseRunning   ResourcePhase = "Running"
	ResourcePhaseSucceeded ResourcePhase = "Succeeded"
	ResourcePhaseFailed    ResourcePhase = "Failed"
	ResourcePhasePaused    ResourcePhase = "Paused"
)

type VerificationMode string

const (
	VerificationModeNone       VerificationMode = "None"
	VerificationModeMetadata   VerificationMode = "Metadata"
	VerificationModeRestoreJob VerificationMode = "RestoreJob"
)

type RestoreTargetMode string

const (
	RestoreTargetModeInPlace    RestoreTargetMode = "InPlace"
	RestoreTargetModeOutOfPlace RestoreTargetMode = "OutOfPlace"
)

type SecretKeyReference struct {
	Name string `json:"name"`
	Key  string `json:"key"`
}

type ServiceReference struct {
	Name      string `json:"name"`
	Namespace string `json:"namespace,omitempty"`
	Port      int32  `json:"port,omitempty"`
}

type NamespacedObjectReference struct {
	APIVersion string `json:"apiVersion,omitempty"`
	Kind       string `json:"kind,omitempty"`
	Namespace  string `json:"namespace,omitempty"`
	Name       string `json:"name"`
}

type EndpointSpec struct {
	Host         string              `json:"host,omitempty"`
	Port         int32               `json:"port,omitempty"`
	Scheme       string              `json:"scheme,omitempty"`
	ServiceRef   *ServiceReference   `json:"serviceRef,omitempty"`
	Username     string              `json:"username,omitempty"`
	UsernameFrom *SecretKeyReference `json:"usernameFrom,omitempty"`
	PasswordFrom *SecretKeyReference `json:"passwordFrom,omitempty"`
}

type BackupScheduleSpec struct {
	Cron                    string                    `json:"cron,omitempty"`
	Suspend                 bool                      `json:"suspend,omitempty"`
	StartingDeadlineSeconds *int64                    `json:"startingDeadlineSeconds,omitempty"`
	ConcurrencyPolicy       batchv1.ConcurrencyPolicy `json:"concurrencyPolicy,omitempty"`
}

type RetentionPolicy struct {
	KeepLast int32 `json:"keepLast,omitempty"`
}

type VerificationSpec struct {
	Enabled bool             `json:"enabled,omitempty"`
	Mode    VerificationMode `json:"mode,omitempty"`
}

type ExecutionTemplateSpec struct {
	RunnerImage        string                      `json:"runnerImage,omitempty"`
	ServiceAccountName string                      `json:"serviceAccountName,omitempty"`
	ImagePullPolicy    corev1.PullPolicy           `json:"imagePullPolicy,omitempty"`
	NodeSelector       map[string]string           `json:"nodeSelector,omitempty"`
	Tolerations        []corev1.Toleration         `json:"tolerations,omitempty"`
	Resources          corev1.ResourceRequirements `json:"resources,omitempty"`
	ExtraEnv           []corev1.EnvVar             `json:"extraEnv,omitempty"`
}

type DriverConfig struct {
	MySQL    *MySQLDriverConfig    `json:"mysql,omitempty"`
	Redis    *RedisDriverConfig    `json:"redis,omitempty"`
	MongoDB  *MongoDBDriverConfig  `json:"mongodb,omitempty"`
	MinIO    *MinIODriverConfig    `json:"minio,omitempty"`
	RabbitMQ *RabbitMQDriverConfig `json:"rabbitmq,omitempty"`
	Milvus   *MilvusDriverConfig   `json:"milvus,omitempty"`
}

type MySQLDriverConfig struct {
	Mode        string   `json:"mode,omitempty"`
	Databases   []string `json:"databases,omitempty"`
	Tables      []string `json:"tables,omitempty"`
	RestoreMode string   `json:"restoreMode,omitempty"`
}

type RedisDriverConfig struct {
	Mode      string   `json:"mode,omitempty"`
	Databases []int32  `json:"databases,omitempty"`
	KeyPrefix []string `json:"keyPrefix,omitempty"`
}

type MongoDBDriverConfig struct {
	Databases         []string `json:"databases,omitempty"`
	Collections       []string `json:"collections,omitempty"`
	IncludeUsersRoles bool     `json:"includeUsersRoles,omitempty"`
}

type MinIODriverConfig struct {
	Buckets         []string `json:"buckets,omitempty"`
	Prefixes        []string `json:"prefixes,omitempty"`
	IncludeVersions bool     `json:"includeVersions,omitempty"`
}

type RabbitMQDriverConfig struct {
	IncludeDefinitions bool     `json:"includeDefinitions,omitempty"`
	Vhosts             []string `json:"vhosts,omitempty"`
	Queues             []string `json:"queues,omitempty"`
}

type MilvusDriverConfig struct {
	Databases            []string `json:"databases,omitempty"`
	Collections          []string `json:"collections,omitempty"`
	IncludeObjectStorage bool     `json:"includeObjectStorage,omitempty"`
}

type RepositoryEndpointSpec struct {
	Path string `json:"path,omitempty"`
}

type NFSRepositorySpec struct {
	Server string `json:"server"`
	Path   string `json:"path"`
}

type S3RepositorySpec struct {
	Endpoint        string              `json:"endpoint"`
	Bucket          string              `json:"bucket"`
	Prefix          string              `json:"prefix,omitempty"`
	Region          string              `json:"region,omitempty"`
	Insecure        bool                `json:"insecure,omitempty"`
	AccessKeyFrom   *SecretKeyReference `json:"accessKeyFrom,omitempty"`
	SecretKeyFrom   *SecretKeyReference `json:"secretKeyFrom,omitempty"`
	SessionTokenRef *SecretKeyReference `json:"sessionTokenFrom,omitempty"`
}

type RestoreTargetSpec struct {
	Mode         RestoreTargetMode          `json:"mode,omitempty"`
	TargetRef    *NamespacedObjectReference `json:"targetRef,omitempty"`
	Endpoint     *EndpointSpec              `json:"endpoint,omitempty"`
	DriverConfig DriverConfig               `json:"driverConfig,omitempty"`
}

type RepositoryRunStatus struct {
	Name      string        `json:"name,omitempty"`
	Phase     ResourcePhase `json:"phase,omitempty"`
	Message   string        `json:"message,omitempty"`
	Snapshot  string        `json:"snapshot,omitempty"`
	UpdatedAt *metav1.Time  `json:"updatedAt,omitempty"`
}
