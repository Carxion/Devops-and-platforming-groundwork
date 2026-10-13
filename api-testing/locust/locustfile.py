"""Locust load test for the Items API: the same lifecycle as k6/lib/items.js.

Locust is here for runners that don't support k6, such as Azure Load Testing
(JMeter and Locust only). Locally:

  pip install locust
  locust -f locustfile.py --config locust.conf --host http://127.0.0.1:8080

Set TOKEN in the environment to send a bearer token.
"""

import os
import uuid

from locust import HttpUser, between, task

TOKEN = os.environ.get("TOKEN", "")


class ItemsUser(HttpUser):
    wait_time = between(0.5, 1.5)

    def on_start(self):
        self.client.headers["Content-Type"] = "application/json"
        if TOKEN:
            self.client.headers["Authorization"] = f"Bearer {TOKEN}"

    @task
    def item_lifecycle(self):
        item_id = f"locust-{uuid.uuid4().hex}"
        url = f"/items/{item_id}"

        # name= groups every ID under one entry in the statistics, named after the
        # spec's operationId so failure criteria can refer to it.
        with self.client.put(url, json={"status": "pending", "quantity": 1}, name="putItem", catch_response=True) as r:
            if r.status_code != 200:
                r.failure(f"PUT returned {r.status_code}")

        with self.client.get(url, name="getItem", catch_response=True) as r:
            if r.status_code != 200 or r.json().get("id") != item_id:
                r.failure(f"GET returned {r.status_code}")

        with self.client.delete(url, name="deleteItem", catch_response=True) as r:
            if r.status_code != 204:
                r.failure(f"DELETE returned {r.status_code}")

        # 404 is the expected answer after a delete.
        with self.client.get(url, name="getItem (deleted)", catch_response=True) as r:
            if r.status_code == 404:
                r.success()
            else:
                r.failure(f"expected 404 after delete, got {r.status_code}")
