"""Short-lived, bounded feature tickets; no image/file persistence or raw-vector input."""
from collections import OrderedDict
import math
import secrets
import threading
import time


class ReviewSessions:
    def __init__(self, ttl_seconds=300, capacity=32, clock=time.monotonic):
        if ttl_seconds <= 0 or capacity < 1:
            raise ValueError('Invalid review session limits')
        self.ttl = ttl_seconds
        self.capacity = capacity
        self.clock = clock
        self.lock = threading.Lock()
        self.entries = OrderedDict()

    def _prune(self, now):
        for key in [key for key, value in self.entries.items() if value['expires'] <= now]:
            del self.entries[key]

    def create(self, part, features):
        features = tuple(float(x) for x in features)
        if len(features) != 768 or any(not math.isfinite(x) for x in features) or not 0 < math.hypot(*features) < float("inf"):
            raise ValueError('Invalid review features')
        with self.lock:
            now = self.clock()
            self._prune(now)
            while len(self.entries) >= self.capacity:
                self.entries.popitem(last=False)
            token = secrets.token_urlsafe(32)
            self.entries[token] = {'part': part, 'features': features, 'expires': now+self.ttl}
        return {'token': token, 'expires_in_seconds': self.ttl, 'part': part}

    def get(self, token):
        with self.lock:
            self._prune(self.clock())
            item = self.entries.get(token)
            if item is None:
                raise KeyError('Review session expired or unavailable')
            return {'part': item['part'], 'features': item['features']}

    def clear(self):
        with self.lock:
            self.entries.clear()
