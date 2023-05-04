#!/bin/bash

session="web"
tmux new-session -d -s $session

tmux rename-window -t $session:0 '2nd'
tmux new-window -t $session:1 -n 'main'
tmux new-window -t $session:2 -n 'cerberus'
tmux send-keys -t $session:2 'cerberus' C-m
tmux new-window -t $session:3 -n 'jz dv'
tmux send-keys -t $session:3 'UBER_RUNTIME_ENVIRONMENT=production jz dv' C-m

echo "web session created"
