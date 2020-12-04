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

package cli

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/ioutil"
	"net/http"

	"github.com/FederatedAI/KubeFATE/k8s-deploy/pkg/api"
	"github.com/rs/zerolog/log"
	"github.com/spf13/viper"
	"github.com/urfave/cli/v2"
	"golang.org/x/net/websocket"
)

func LogCommand() *cli.Command {
	return &cli.Command{
		Name: "log",
		Flags: []cli.Flag{
			&cli.BoolFlag{
				Name:    "follow",
				Aliases: []string{"f"},
				Value:   false,
				Usage:   "Specify if the logs should be streamed.",
			},
		},
		Usage: "Get this cluster module log",
		Action: func(c *cli.Context) error {

			var uuid string
			if c.Args().Len() > 0 {
				uuid = c.Args().Get(0)
			} else {
				return errors.New("not uuid")
			}

			var module string
			if c.Args().Len() > 1 {
				module = c.Args().Get(1)
			} else {
				return errors.New("not module")
			}

			follow := c.Bool("follow")
			if follow {
				return GetModuleLogFollow(uuid, module)
			}

			kubeLog, err := GetModuleLog(uuid, module)
			if err != nil {
				return err
			}
			fmt.Println(kubeLog)
			return nil
		},
	}
}

func GetModuleLog(uuid, module string) (string, error) {
	r := &Request{
		Type: "GET",
		Path: "log",
		Body: nil,
	}

	serviceUrl := viper.GetString("serviceurl")
	apiVersion := api.ApiVersion + "/"
	if serviceUrl == "" {
		serviceUrl = "localhost:8080/"
	}
	Url := "http://" + serviceUrl + "/" + apiVersion + r.Path + fmt.Sprintf("/%s/%s", uuid, module)

	body := bytes.NewReader(r.Body)
	log.Debug().Str("Type", r.Type).Str("url", Url).Msg("Request")
	request, err := http.NewRequest(r.Type, Url, body)
	if err != nil {
		return "", err
	}

	token, err := getToken()
	if err != nil {
		return "", err
	}
	Authorization := fmt.Sprintf("Bearer %s", token)

	request.Header.Add("Authorization", Authorization)

	resp, err := http.DefaultClient.Do(request)
	if err != nil {
		return "", err
	}
	respBody, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	if resp.StatusCode != 200 {
		type LogResultErr struct {
			Error string
		}

		logResultErr := new(LogResultErr)

		err = json.Unmarshal(respBody, &logResultErr)
		if err != nil {
			return "", err
		}

		return "", fmt.Errorf("resp.StatusCode=%d, error: %s", resp.StatusCode, logResultErr.Error)
	}

	type LogResultMsg struct {
		Msg  string
		Data string
	}

	LogResult := new(LogResultMsg)

	err = json.Unmarshal(respBody, &LogResult)
	if err != nil {
		return "", err
	}

	log.Debug().Int("Code", resp.StatusCode).Msg("ok")
	return LogResult.Data, err
}

func GetModuleLogFollow(uuid, module string) error {

	r := &Request{
		Type: "GET",
		Path: "log",
		Body: nil,
	}

	serviceUrl := viper.GetString("serviceurl")
	apiVersion := api.ApiVersion + "/"
	if serviceUrl == "" {
		serviceUrl = "localhost:8080/"
	}
	Url := "ws://" + serviceUrl + "/" + apiVersion + r.Path + fmt.Sprintf("/%s/%s/ws", uuid, module)
	log.Debug().Str("Url", Url).Msg("ok")

	config, err := websocket.NewConfig(Url, "http://"+serviceUrl+"/")
	config.Header.Add("user-agent", "kubefate")

	token, err := getToken()
	if err != nil {
		return err
	}
	Authorization := fmt.Sprintf("Bearer %s", token)
	config.Header.Add("Authorization", Authorization)
	ws, err := websocket.DialConfig(config)
	if err != nil {
		return err
	}
	defer ws.Close()

	for {
		var msg string
		err = websocket.Message.Receive(ws, &msg)
		if err != nil {
			if err != io.EOF {
				log.Err(err).Msg("Receive form websocket error")
				return err
			}
			log.Debug().Err(err).Msg("Receive io.EOF")
			return nil
		}
		fmt.Printf(msg)
	}
}
