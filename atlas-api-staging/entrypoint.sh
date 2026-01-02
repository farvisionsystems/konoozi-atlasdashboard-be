#!/bin/bash
set -e

mix ecto.setup

exec /app/_build/prod/rel/atlas/bin/server

