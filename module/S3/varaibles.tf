variable "name" {
    validation {
    condition     = length(var.name) >= 1 && length(var.name) <= 40 && length(regexall("[^a-zA-Z0-9-]", var.name)) == 0
    error_message = "The bucket name must be at least 1 character, no more than 40 characters, and only contain letters, numbers, and hyphens."
  }
}

variable "prefix" {
    validation {
    condition     = length(var.prefix) >= 1 && length(var.prefix) <= 20 && length(regexall("[^a-zA-Z0-9-]", var.prefix)) == 0
    error_message = "The bucket prefix must be at least 1 character, no more than 20 characters, and only contain letters, numbers, and hyphens."
  }
}