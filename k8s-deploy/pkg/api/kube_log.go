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
	"errors"

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
		kubeLog.GET("/:clusterID", e.getClusterLog)
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

	buf, err := service.GetLogs(&service.LogChanArgs{
		Name:      cluster.Name,
		Namespace: cluster.NameSpace,
		Container: containerName,
		Follow:    false,
	})

	if err != nil {
		log.Error().Err(err).Msg("request error")
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	log.Debug().Int("data.size", buf.Len()).Msg("getClusterLog success")
	c.JSON(200, gin.H{"data": buf.String(), "msg": "getClusterLog success"})

}

func (_ *kubeLog) getClusterLogWs(c *gin.Context) {

	clusterID := c.Param("clusterID")
	if clusterID == "" {
		log.Error().Err(errors.New("not exit clusterID")).Msg("request error")
		c.JSON(400, gin.H{"error": "not exit clusterID"})
		return
	}

	containerName := c.Param("containerName")

	hc := modules.Cluster{Uuid: clusterID}
	cluster, err := hc.Get()
	if err != nil {
		log.Error().Err(err).Str("uuid", clusterID).Msg("get cluster error")
		c.JSON(400, gin.H{"error": "get cluster error, " + err.Error()})
		return
	}

	handler := websocket.Handler(func(c *websocket.Conn) {
		log.Debug().Msg("get log websocket reader success")
		defer log.Debug().Msg("websocket close")

		err := service.WriteLog(c, &service.LogChanArgs{
			Name:      cluster.Name,
			Namespace: cluster.NameSpace,
			Container: containerName,
			Follow:    true,
		})
		log.Warn().Err(err).Msg("writeLog err, if the log stream is closed, you can ignore this prompt")
	})
	handler.ServeHTTP(c.Writer, c.Request)
}
