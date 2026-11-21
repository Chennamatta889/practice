import json
import os
from pathlib import Path
import subprocess
import sys
import time
import unittest
import urllib.request


class ServiceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        env = {**os.environ, 'APP_NAME': 'testing', 'VERSION': '9.8.7', 'PORT': '18765'}
        cls.process = subprocess.Popen([sys.executable, str(Path(__file__).with_name('app.py'))], env=env,
                                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for _ in range(50):
            try:
                urllib.request.urlopen('http://127.0.0.1:18765/healthz', timeout=.2)
                break
            except Exception:
                time.sleep(.1)
        else:
            raise RuntimeError('service did not start')

    @classmethod
    def tearDownClass(cls):
        cls.process.terminate()
        cls.process.wait(timeout=5)

    def test_root(self):
        with urllib.request.urlopen('http://127.0.0.1:18765/') as response:
            data = json.load(response)
            self.assertEqual(response.status, 200)
            self.assertEqual(data['app'], 'testing')
            self.assertEqual(data['version'], '9.8.7')
            self.assertTrue(data['pod'])

    def test_healthz(self):
        with urllib.request.urlopen('http://127.0.0.1:18765/healthz') as response:
            self.assertEqual(response.status, 200)


if __name__ == '__main__':
    unittest.main()
