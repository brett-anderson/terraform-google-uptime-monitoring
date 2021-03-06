/**
 * Copyright 2019 Taito United
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

resource "google_monitoring_uptime_check_config" "https" {
  count = length(var.uptime_targets)

  project      = var.project_id
  display_name = "${var.project}-${var.env}-${var.uptime_targets[count.index]}"
  timeout      = "${var.uptime_timeouts[count.index]}s"

  monitored_resource {
    type = "uptime_url"
    labels = {
      host = var.domain
    }
  }

  http_check {
    use_ssl = true
    port    = 443
    path    = var.uptime_paths[count.index]
  }
}

resource "google_monitoring_alert_policy" "https" {
  depends_on = [google_monitoring_uptime_check_config.https]
  count      = length(var.uptime_targets) > 0 ? 1 : 0
  enabled    = "true"

  project               = var.project_id
  display_name          = "${var.project}-${var.env}"
  notification_channels = var.uptime_channels

  combiner = "OR"
  dynamic "conditions" {
    for_each = var.uptime_targets

    content {
      display_name = "${var.project}-${var.env}-${conditions.value}"

      condition_threshold {
        aggregations {
          alignment_period     = "1200s"
          cross_series_reducer = "REDUCE_COUNT_FALSE"
          group_by_fields = [
            "resource.*",
          ]
          per_series_aligner = "ALIGN_NEXT_OLDER"
        }
        comparison      = "COMPARISON_GT"
        duration        = "60s"
        filter          = "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" resource.type=\"uptime_url\" metric.label.\"check_id\"=\"${var.project}-${var.env}-${conditions.value}\""
        threshold_value = "1.0"
        trigger {
          count = 1
        }
      }
    }
  }
}
