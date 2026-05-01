#!/usr/bin/env node

/**
 * morpheus-client.js — Simple WebSocket client for Morpheus Engine API
 * 
 * Usage from bash:
 *   node morpheus-client.js create-session '{"project":"/path","host":{"type":"remote","hostname":"sth-go.devpod-nld"}}'
 *   node morpheus-client.js get-sessions
 *   node morpheus-client.js close-session '<session-id>'
 * 
 * Or use as a library in Node scripts.
 */

const WebSocket = require('ws');
const { randomUUID } = require('crypto');

class MorpheusClient {
  constructor(url = 'ws://localhost:3100') {
    this.url = url;
    this.ws = null;
    this.pendingRequests = new Map();
    this.connected = false;
  }

  connect() {
    return new Promise((resolve, reject) => {
      this.ws = new WebSocket(this.url);
      
      this.ws.on('open', () => {
        this.connected = true;
        resolve();
      });

      this.ws.on('error', (err) => {
        reject(err);
      });

      this.ws.on('message', (data) => {
        try {
          const msg = JSON.parse(data.toString());
          this.handleMessage(msg);
        } catch (err) {
          console.error('Failed to parse message:', err);
        }
      });

      this.ws.on('close', () => {
        this.connected = false;
      });
    });
  }

  handleMessage(msg) {
    if (msg.type === 'rpc-response') {
      const pending = this.pendingRequests.get(msg.id);
      if (pending) {
        this.pendingRequests.delete(msg.id);
        if (msg.error) {
          pending.reject(new Error(msg.error.message));
        } else {
          pending.resolve(msg.result);
        }
      }
    } else if (msg.type === 'push-event') {
      // Ignore push events in CLI mode
    }
  }

  call(method, ...params) {
    return new Promise((resolve, reject) => {
      if (!this.connected) {
        reject(new Error('Not connected to Morpheus server'));
        return;
      }

      const id = randomUUID();
      const request = {
        type: 'rpc-request',
        id,
        method,
        params
      };

      this.pendingRequests.set(id, { resolve, reject });

      this.ws.send(JSON.stringify(request), (err) => {
        if (err) {
          this.pendingRequests.delete(id);
          reject(err);
        }
      });

      // Timeout after 30s
      setTimeout(() => {
        if (this.pendingRequests.has(id)) {
          this.pendingRequests.delete(id);
          reject(new Error(`Request timeout: ${method}`));
        }
      }, 30000);
    });
  }

  async createSession(opts) {
    return this.call('createSession', opts);
  }

  async getSessions() {
    return this.call('getSessions');
  }

  async closeSession(id) {
    return this.call('closeSession', id);
  }

  async deleteSession(id) {
    return this.call('deleteSession', id);
  }

  async renameSession(id, name) {
    return this.call('renameSession', id, name);
  }

  async getDevPods() {
    return this.call('getDevPods');
  }

  async sendTerminalInput(id, data) {
    return this.call('sendTerminalInput', id, data);
  }

  close() {
    if (this.ws) {
      this.ws.close();
    }
  }
}

// CLI mode
if (require.main === module) {
  const [,, command, ...args] = process.argv;

  if (!command) {
    console.error('Usage: morpheus-client.js <command> [args...]');
    console.error('');
    console.error('Commands:');
    console.error('  create-session <json-opts>');
    console.error('  get-sessions');
    console.error('  close-session <id>');
    console.error('  delete-session <id>');
    console.error('  rename-session <id> <name>');
    console.error('  get-devpods');
    process.exit(1);
  }

  const client = new MorpheusClient();

  async function run() {
    await client.connect();

    let result;
    switch (command) {
      case 'create-session': {
        const opts = JSON.parse(args[0]);
        result = await client.createSession(opts);
        break;
      }
      case 'get-sessions':
        result = await client.getSessions();
        break;
      case 'close-session':
        result = await client.closeSession(args[0]);
        break;
      case 'delete-session':
        result = await client.deleteSession(args[0]);
        break;
      case 'rename-session':
        result = await client.renameSession(args[0], args[1]);
        break;
      case 'get-devpods':
        result = await client.getDevPods();
        break;
      default:
        throw new Error(`Unknown command: ${command}`);
    }

    console.log(JSON.stringify(result, null, 2));
    client.close();
  }

  run().catch((err) => {
    console.error('Error:', err.message);
    client.close();
    process.exit(1);
  });
}

module.exports = { MorpheusClient };
