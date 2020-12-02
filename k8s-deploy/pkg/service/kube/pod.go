package kube

import (
	"context"

	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// GetPod is get a pod info
func (e *Kube) GetPod(podName, namespace string) (*corev1.Pod, error) {
	pod, err := e.client.CoreV1().Pods(namespace).Get(context.Background(), podName, metav1.GetOptions{})
	return pod, err
}

// GetPods is get pod list info
func (e *Kube) GetPods(name, namespace, LabelSelector string) (*corev1.PodList, error) {
	pods, err := e.client.CoreV1().Pods(namespace).List(context.Background(), metav1.ListOptions{LabelSelector: LabelSelector})
	return pods, err
}
