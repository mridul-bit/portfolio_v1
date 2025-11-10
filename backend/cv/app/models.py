from django.db import models

class DownloadLog(models.Model):
    file_key = models.CharField(max_length=255)
    timestamp = models.DateTimeField(auto_now_add=True)
    requester_ip = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.CharField(max_length=255, null=True, blank=True)
    status = models.CharField(max_length=50, default="PENDING")
    log_id = models.UUIDField(unique=True, null=True, auto_created=True) # Optional unique ID
    
    class Meta:
        ordering = ['-timestamp']

    def __str__(self):
        return f"{self.file_key} at {self.timestamp}"