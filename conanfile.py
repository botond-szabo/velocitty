import os
from conan import ConanFile
from conan.tools.files import copy
from conan.errors import ConanInvalidConfiguration

class Velocitty(ConanFile):
    name = "velocitty"
    version = "1.0.0"
    package_type = "shared-library"
    settings = "os", "arch", "compiler", "build_type"

    def validate(self):
        if self.settings.os != "Macos":
            raise ConanInvalidConfiguration("This prebuilt package only supports macOS.")

    def package(self):
        copy(self, "*.h",
            src=os.path.join(self.source_folder, "include"),
            dst=os.path.join(self.package_folder, "include"))