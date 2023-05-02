#!/bin/bash

session="web"
tmux new-session -d -s $session

tmux rename-window -t $session:1 'ssh'
tmux send-keys -t $session:1 'ssh sth.devpod-nld' C-m 'tmux' C-m
tmux split-window -hf -t $session:1 
tmux send-keys -t $session:1 'podfwd' C-m

echo "web session created"
