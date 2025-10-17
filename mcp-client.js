// mcp-client.js
import { spawn } from 'child_process';
import { EventEmitter } from 'events';

export class MCPClient extends EventEmitter {
  constructor(serverScript = './mcp_suricata_server.py') {
    super();
    this.serverScript = serverScript;
    this.process = null;
    this.requestId = 0;
    this.pendingRequests = new Map();
    this.buffer = '';
  }

  async connect() {
    return new Promise((resolve, reject) => {
      this.process = spawn('python3', [this.serverScript]);
      
      this.process.stdout.on('data', (data) => {
        this.buffer += data.toString();
        this.processBuffer();
      });

      this.process.stderr.on('data', (data) => {
        console.error('[MCP Server Error]', data.toString());
      });

      this.process.on('error', (error) => {
        console.error('[MCP Server Process Error]', error);
        reject(error);
      });

      this.process.on('close', (code) => {
        console.log(`[MCP Server] Process exited with code ${code}`);
        this.emit('disconnect');
      });

      // 초기화 메시지 전송
      this.sendRequest('initialize', {
        protocolVersion: '2024-11-05',
        capabilities: {
          roots: { listChanged: true },
          sampling: {}
        },
        clientInfo: {
          name: 'suricata-dashboard',
          version: '1.0.0'
        }
      }).then(() => {
        console.log('[MCP Client] Connected to server');
        resolve();
      }).catch(reject);
    });
  }

  processBuffer() {
    const lines = this.buffer.split('\n');
    this.buffer = lines.pop() || '';

    for (const line of lines) {
      if (!line.trim()) continue;
      
      try {
        const message = JSON.parse(line);
        this.handleMessage(message);
      } catch (e) {
        console.error('[MCP Client] Parse error:', e.message);
      }
    }
  }

  handleMessage(message) {
    if (message.id !== undefined && this.pendingRequests.has(message.id)) {
      const { resolve, reject } = this.pendingRequests.get(message.id);
      this.pendingRequests.delete(message.id);

      if (message.error) {
        reject(new Error(message.error.message || 'Unknown error'));
      } else {
        resolve(message.result);
      }
    } else if (message.method === 'notifications/message') {
      this.emit('notification', message.params);
    }
  }

  sendRequest(method, params = {}) {
    return new Promise((resolve, reject) => {
      const id = ++this.requestId;
      
      const request = {
        jsonrpc: '2.0',
        id,
        method,
        params
      };

      this.pendingRequests.set(id, { resolve, reject });
      
      const message = JSON.stringify(request) + '\n';
      this.process.stdin.write(message);

      // 타임아웃 설정
      setTimeout(() => {
        if (this.pendingRequests.has(id)) {
          this.pendingRequests.delete(id);
          reject(new Error('Request timeout'));
        }
      }, 30000);
    });
  }

  async listTools() {
    const result = await this.sendRequest('tools/list');
    return result.tools || [];
  }

  async callTool(name, args = {}) {
    const result = await this.sendRequest('tools/call', {
      name,
      arguments: args
    });
    return result;
  }

  async getRecentAlerts(count = 10) {
    const result = await this.callTool('get_recent_alerts', { count });
    const content = result.content?.[0]?.text;
    return content ? JSON.parse(content) : { count: 0, alerts: [] };
  }

  async getAlertStats() {
    const result = await this.callTool('get_alert_stats', {});
    const content = result.content?.[0]?.text;
    return content ? JSON.parse(content) : {};
  }

  async searchAlerts(query) {
    const result = await this.callTool('search_alerts', { query });
    const content = result.content?.[0]?.text;
    return content ? JSON.parse(content) : { results: 0, alerts: [] };
  }

  async blockIP(ip, reason = 'Security threat') {
    const result = await this.callTool('block_ip', { ip, reason });
    return result.content?.[0]?.text || 'Unknown result';
  }

  disconnect() {
    if (this.process) {
      this.process.kill();
      this.process = null;
    }
    this.pendingRequests.clear();
  }
}

// 싱글톤 인스턴스
let clientInstance = null;

export async function getMCPClient() {
  if (!clientInstance) {
    clientInstance = new MCPClient('./mcp_suricata_server.py');
    await clientInstance.connect();
  }
  return clientInstance;
}