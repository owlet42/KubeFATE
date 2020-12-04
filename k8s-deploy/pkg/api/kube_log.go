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

package api

import (
	"bufio"
	"errors"
	"io"
	"time"

	"github.com/FederatedAI/KubeFATE/k8s-deploy/pkg/modules"
	"github.com/FederatedAI/KubeFATE/k8s-deploy/pkg/service"
	"github.com/gin-gonic/gin"
	"github.com/rs/zerolog/log"
	"golang.org/x/net/websocket"
)

type kubeLog struct {
}

type logResult struct {
	data string
	msg  string
}

func (e *kubeLog) Router(r *gin.RouterGroup) {
	authMiddleware, _ := GetAuthMiddleware()
	kubeLog := r.Group("/log")
	kubeLog.Use(authMiddleware.MiddlewareFunc())
	{
		kubeLog.GET("/:clusterID/:containerName", e.getClusterLog)
		kubeLog.GET("/:clusterID/:containerName/ws", e.getClusterLogWs)
	}
}

func (_ *kubeLog) getClusterLog(c *gin.Context) {

	clusterID := c.Param("clusterID")
	if clusterID == "" {
		log.Error().Err(errors.New("not exit clusterID")).Msg("request error")
		c.JSON(400, gin.H{"error": "not exit clusterID"})
		return
	}

	containerName := c.Param("containerName")
	if clusterID == "" {
		log.Error().Err(errors.New("not exit containerName")).Msg("request error")
		c.JSON(400, gin.H{"error": "not exit containerName"})
		return
	}

	hc := modules.Cluster{Uuid: clusterID}
	cluster, err := hc.Get()
	if err != nil {
		log.Error().Err(err).Str("uuid", clusterID).Msg("get cluster error")
		c.JSON(400, gin.H{"error": "get cluster error, " + err.Error()})
		return
	}

	containerLogs, err := getModuleLogs(cluster, containerName)
	if err != nil {
		log.Error().Err(err).Msg("request error")
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	log.Debug().Int("data.size", len(containerLogs)).Msg("getClusterLog success")
	c.JSON(200, gin.H{"data": containerLogs, "msg": "getClusterLog success"})

}

func getModuleLogs(cluster modules.Cluster, containerName string) (string, error) {
	return service.GetLogs(cluster.NameSpace, cluster.Name, containerName)
}

func (_ *kubeLog) getClusterLogWs(c *gin.Context) {

	clusterID := c.Param("clusterID")
	if clusterID == "" {
		log.Error().Err(errors.New("not exit clusterID")).Msg("request error")
		c.JSON(400, gin.H{"error": "not exit clusterID"})
		return
	}

	containerName := c.Param("containerName")
	if clusterID == "" {
		log.Error().Err(errors.New("not exit containerName")).Msg("request error")
		c.JSON(400, gin.H{"error": "not exit containerName"})
		return
	}

	hc := modules.Cluster{Uuid: clusterID}
	cluster, err := hc.Get()
	if err != nil {
		log.Error().Err(err).Str("uuid", clusterID).Msg("get cluster error")
		c.JSON(400, gin.H{"error": "get cluster error, " + err.Error()})
		return
	}

	logRead, err := service.GetLogFollow(cluster.NameSpace, cluster.Name, containerName)
	if err != nil {
		log.Error().Err(err).Str("uuid", clusterID).Msg("get cluster error")
		c.JSON(500, gin.H{"error": "get cluster error, " + err.Error()})
		return
	}
	defer logRead.Close()

	log.Debug().Msg("get log follow reader success")

	handler := websocket.Handler(func(c *websocket.Conn) {

		msg := make(chan string)
		stop := make(chan bool)
		go readString(logRead, msg, stop)

		for {
			select {
			case l := <-msg:
				err = websocket.Message.Send(c, l)
				if err != nil {
					log.Err(err).Msg("Write")
					return
				}
				// log.Debug().Str("l", l).Msg("send : ")
			case <-stop:
				c.Close()
				return
			default:
				err = websocket.Message.Send(c, "")
				if err != nil {
					log.Warn().Err(err).Msg("Msg Send error")
					return
				}
				time.Sleep(time.Millisecond)
			}

		}

	})
	handler.ServeHTTP(c.Writer, c.Request)

}

func readString(logRead io.ReadCloser, msg chan string, stop chan bool) error {
	r := bufio.NewReader(logRead)
	for {
		msgstr, err := r.ReadString('\n')
		if err != nil {
			if err != io.EOF {
				log.Warn().Err(err).Msg("ReadLine form logRead error")
				return err
			}
			log.Debug().Err(err).Msg("ReadString io.EOF")
			stop <- true
			return nil
		}
		msg <- msgstr
	}

}
