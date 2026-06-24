from django.contrib.staticfiles.management.commands.runserver import Command as StaticfilesRunserverCommand


class Command(StaticfilesRunserverCommand):
    """Run the report server without Django's migration startup probe."""

    def check_migrations(self) -> None:
        return None
