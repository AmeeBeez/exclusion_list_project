import getpass
import os
import sys

from django.contrib.staticfiles.management.commands.runserver import Command as StaticfilesRunserverCommand


class Command(StaticfilesRunserverCommand):
    """Run the report server with a local PostgreSQL password prompt."""

    def execute(self, *args, **options):
        if "POSTGRES_PASSWORD" not in os.environ and sys.stdin.isatty():
            os.environ["POSTGRES_PASSWORD"] = getpass.getpass(
                "PostgreSQL password (press Enter for blank): "
            )
        return super().execute(*args, **options)

    def check_migrations(self) -> None:
        return None
