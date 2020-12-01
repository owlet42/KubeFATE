package kube

import (
	"context"

	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/labels"
)

func (e *Kube) GetPod(name, namespace string, labels labels.Labels) (*corev1.Pod, error) {

	pod, err := e.client.CoreV1().Pods(namespace).Get(context.Background(), "", metav1.GetOptions{})
	return pod, err
}

func (e *Kube) GetPods(name, namespace string, labels labels.Labels) (*corev1.PodList, error) {

	pods, err := e.client.CoreV1().Pods(namespace).List(context.Background(), metav1.ListOptions{})
	return pods, err
}
