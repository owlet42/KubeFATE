package kube

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"os"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"

	"github.com/pkg/errors"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/labels"
)

func (e *Kube) GetLog(name, namespace string, labels labels.Labels) {

	pod, err := e.client.CoreV1().Pods(namespace).List(context.Background(), metav1.ListOptions{})
	podName := pod.Items[0].ObjectMeta.Name
	containerName := pod.Items[0].Spec.Containers[0].Name
	fmt.Println("podName", podName)
	fmt.Println("containerName", containerName)
	fmt.Println("namespace", namespace)

	logReader, err := e.client.CoreV1().Pods(namespace).GetLogs(podName, &corev1.PodLogOptions{Container: containerName}).Stream(context.Background())
	if err != nil {
		fmt.Println(err)
		return
	}

	fmt.Fprintf(os.Stdout, "POD LOGS: %s\n", podName)
	_, err = io.Copy(os.Stdout, logReader)
	fmt.Fprintln(os.Stdout)
	if err != nil {
		fmt.Println(errors.Wrapf(err, "unable to write pod logs for %s", podName))
		return
	}
	return
}

func (e *Kube) getPodLogs(pod *corev1.Pod) string {
	podLogOpts := corev1.PodLogOptions{}

	req := e.client.CoreV1().Pods(pod.Namespace).GetLogs(pod.Name, &podLogOpts)
	podLogs, err := req.Stream(context.Background())
	if err != nil {
		return "error in opening stream: " + err.Error()
	}
	defer podLogs.Close()

	buf := new(bytes.Buffer)
	_, err = io.Copy(buf, podLogs)
	if err != nil {
		return "error in copy information from podLogs to buf"
	}
	str := buf.String()

	return str
}
