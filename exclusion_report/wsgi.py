"""WSGI config for the exclusion report project."""

import os

from django.core.wsgi import get_wsgi_application


os.environ.setdefault("DJANGO_SETTINGS_MODULE", "exclusion_report.settings")

application = get_wsgi_application()
