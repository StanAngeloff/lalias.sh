#!/bin/sh
# **lalias** is [Zsh][zsh] shell extension that allows you to have
# directory-specific command aliases. It is intended as a development tool.
#
# The original idea was to allow locally installed [Node.js][node] modules to
# be used without having to put them on `$PATH`.
#
# Usage
# -----
#
# To use this script, source it in your `~/.zshrc` file. For each directory
# you want to have aliases available in, create an `.aliases` file and add
# each command on a separate line:
#
#     say=echo
#     jake=./app/node_modules/.bin/jake  # ./ is relative to the .aliases file
#
# __NOTE__: you can only use commands that don't have a binding yet, e.g., if
# you have a `jake` binary on path, it will be executed. This script only runs
# for commands that are not found.
#
# [zsh]: http://www.zsh.org/
# [node]: http://nodejs.org

# Functions
# ---------

# Checks if a function is defined.
#
# `$?` is `0` if the function exists, `1` otherwise.
lalias_function_exists() {
  declare -f $1 > /dev/null
}

# Saves a function under a new name if it doesn't already exist.
lalias_function_save() {
  local original_function
  local new_function
  lalias_function_exists $2 || {
    # Substitute the original function name with the new one and evaluate.
    # This generates a copy under the new name.
    original_function=$(declare -f $1)
    new_function="$2${original_function#$1}"
    eval "$new_function"
  }
}

# Script
# ------

# In order to prevent this script executing itself over and over again, add
# a global variable to track nesting level.
LALIAS_LEVEL=0

# By default we are running as a shell script.
LALIAS_ZSH=0

# Check if we are running inside Zsh.
if type setopt 2>/dev/null | grep -q 'shell builtin'; then
  LALIAS_ZSH=1
else
  # We are running on the command-line.  
  # Someone once said this was the most important line in any shell program.
  set -e
fi

# Set the default basename for the configuration file. This can be overwritten
# by setting the `LALIAS_BASENAME` (environment) variable before sourcing this
# script file.
if [ -z "$LALIAS_BASENAME" ]; then
  LALIAS_BASENAME='.aliases'
fi

# Check if `command_not_found_handler` is already defined.
if lalias_function_exists command_not_found_handler; then
  # If it is, save it under a new name so it can be used in case the script
  # fails to find a local alias to execute.
  lalias_function_save command_not_found_handler lalias_previous_handler
fi

# When Zsh fails to execute a command, it calls `command_not_found_handler`.
command_not_found_handler() {
  local exit_code
  # Forward all arguments to `lalias_command` and attempt to find a
  # suitable replacement.
  lalias_command $* || {
    exit_code=$?
    # If there are no suitable command, revert to the previous handler
    # if one was defined.
    if lalias_function_exists lalias_previous_handler; then
      lalias_previous_handler $*
      exit_code=$?
    fi
    # Return the last code. If it was a failure this instructs Zsh to take the
    # default action and print a 'command not found' statement. If it was a
    # success, Zsh is silent and the command is considered handled.
    return $exit_code
  }
}

lalias_command() {
  local previous_ifs
  local parts
  local slice
  local directory
  local file
  local aliases
  # Allow a maximum of 5 levels of nesting.
  if [ "$LALIAS_LEVEL" -gt 5 ]; then
    return 2
  fi
  let LALIAS_LEVEL++
  # Enable Zsh shell word splitting to mimic sh/bash behaviour.
  if [ $LALIAS_ZSH -eq 1 ]; then
    setopt shwordsplit
  fi
  # Split the current working directory path into an array.
  previous_ifs="$IFS"
  IFS='/'
  parts=( $PWD )
  aliases=( "$HOME/.aliases" )
  # Iterate over the parts of the array backwards.
  for i in {${#parts[@]}..1}; do
    # Create each part by taking a slice and joining all pieces.
    slice=( ${parts[@]:0:$i} )
    directory="${slice[*]}"
    # Test if the target directory is empty and skip.
    if [ -n "$directory" ]; then
      # Create the path and check if there is a file at that location.
      file="$directory/$LALIAS_BASENAME"
      if [ -e "$file" ]; then
        # Push to the beginning of the list.
        aliases=("$file" "${aliases[@]}")
      fi
    fi
  done
  # Restore the previous value of the Internal Field Separator.
  IFS="$previous_ifs"
  let LALIAS_LEVEL--
  # If we found at least one `.aliases` file, process each individually.
  if [ ${#aliases[@]} -gt 0 ]; then
    for file in "${aliases[@]}"; do
      if [ -n "$file" ] && [ -e "$file" ]; then
        lalias_process $file $*
        if [ $? -eq 0 ]; then
          return 0
        fi
      fi
    done
  fi
  return 1
}

lalias_process() {
  local alias
  local command
  # Look up the command in the `.aliases` file and take the last occurrence.
  alias=$( cat "$1" | grep "^\\(alias \\)\\?$2=" | tail -1 )
  if [ -z "$alias" ]; then
    return 1
  fi
  # Chop everything before the `=` character and substitute `./` in the
  # command for the directory of the `.aliases` file.
  command="${${alias#*=}/#.\//$( dirname "$1" )/}"
  # Evaluate and return exit code.
  eval "$command ${${@:3}[*]}"
  return $?
}
