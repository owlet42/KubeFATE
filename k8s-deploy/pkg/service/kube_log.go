/*
 * Copyright 2019-2020 VMware, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * http://www.apache.org/licenses/LICENSE-2.0
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

package service

import (
	"bytes"
	"io"
)

// GetLogs is Get container Logs
func GetLogs(namespace, Name, containerName string) (string, error) {

	podName, err := GetPodNameByModule(GetDefaultNamespace(namespace), Name, containerName)
	if err != nil {
		return "", err
	}

	read, err := KubeClient.GetPodLogs(GetDefaultNamespace(namespace), podName, containerName, false)
	if err != nil {
		return "", err
	}
	defer read.Close()

	buf := new(bytes.Buffer)
	_, err = io.Copy(buf, read)
	if err != nil {
		return "", err
	}
	str := buf.String()

	return str, nil
}

// GetLogFollow is Get container Logs
func GetLogFollow(namespace, Name, containerName string) (io.ReadCloser, error) {

	podName, err := GetPodNameByModule(GetDefaultNamespace(namespace), Name, containerName)
	if err != nil {
		return nil, err
	}
	return KubeClient.GetPodLogs(GetDefaultNamespace(namespace), podName, containerName, true)
}
