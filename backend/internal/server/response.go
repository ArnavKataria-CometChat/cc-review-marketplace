package server

import "github.com/gin-gonic/gin"

// errorJSON writes a consistent error envelope.
func errorJSON(c *gin.Context, status int, msg string) {
	c.AbortWithStatusJSON(status, gin.H{"error": msg})
}
