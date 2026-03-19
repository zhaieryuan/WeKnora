#!/usr/bin/env python3
"""
DocReader Web 测试界面
启动后可在浏览器中打开 http://localhost:8000 进行测试
"""
import os
import base64
from flask import Flask, render_template_string, request, jsonify
import grpc
from docreader.proto import docreader_pb2, docreader_pb2_grpc

app = Flask(__name__)

# gRPC 服务地址
GRPC_ADDRESS = os.environ.get('DOCREADER_GRPC_ADDRESS', 'localhost:50051')

HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DocReader API 测试界面</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            max-width: 1000px;
            margin: 0 auto;
        }
        .header {
            background: white;
            padding: 24px;
            border-radius: 12px;
            margin-bottom: 20px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        }
        .header h1 {
            color: #333;
            margin-bottom: 8px;
        }
        .header p {
            color: #666;
            font-size: 14px;
        }
        .status {
            display: inline-block;
            padding: 4px 12px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 500;
            margin-left: 10px;
        }
        .status.connected {
            background: #10b981;
            color: white;
        }
        .status.disconnected {
            background: #ef4444;
            color: white;
        }
        .card {
            background: white;
            padding: 24px;
            border-radius: 12px;
            margin-bottom: 20px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        }
        .card h2 {
            color: #333;
            margin-bottom: 16px;
            font-size: 18px;
        }
        .form-group {
            margin-bottom: 16px;
        }
        label {
            display: block;
            color: #555;
            margin-bottom: 6px;
            font-size: 14px;
            font-weight: 500;
        }
        input[type="text"],
        input[type="number"],
        select,
        textarea {
            width: 100%;
            padding: 10px 12px;
            border: 1px solid #ddd;
            border-radius: 6px;
            font-size: 14px;
            transition: border-color 0.2s;
        }
        input:focus, select:focus, textarea:focus {
            outline: none;
            border-color: #667eea;
        }
        textarea {
            min-height: 100px;
            font-family: monospace;
        }
        .file-input {
            border: 2px dashed #ddd;
            border-radius: 6px;
            padding: 30px;
            text-align: center;
            cursor: pointer;
            transition: all 0.2s;
        }
        .file-input:hover {
            border-color: #667eea;
            background: #f8f9ff;
        }
        .file-input.dragover {
            border-color: #667eea;
            background: #f0f4ff;
        }
        .file-input input {
            display: none;
        }
        .btn {
            padding: 10px 24px;
            border: none;
            border-radius: 6px;
            font-size: 14px;
            font-weight: 500;
            cursor: pointer;
            transition: all 0.2s;
            background: #667eea;
            color: white;
        }
        .btn:hover {
            background: #5568d3;
            transform: translateY(-1px);
        }
        .btn:disabled {
            background: #ccc;
            cursor: not-allowed;
        }
        .btn-secondary {
            background: #6b7280;
        }
        .btn-secondary:hover {
            background: #4b5563;
        }
        .response {
            background: #1e293b;
            color: #e2e8f0;
            padding: 16px;
            border-radius: 8px;
            margin-top: 16px;
            max-height: none;
            overflow-y: auto;
            font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
            font-size: 13px;
            line-height: 1.5;
        }
        .response.error {
            background: #1e1e1e;
            color: #ef4444;
        }
        .response.success {
            background: #1e293b;
        }
        .tag {
            display: inline-block;
            padding: 2px 8px;
            background: #e0e7ff;
            color: #4338ca;
            border-radius: 4px;
            font-size: 12px;
            margin: 2px;
        }
        .engine-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
            gap: 12px;
            margin-top: 12px;
        }
        .engine-card {
            background: #f8fafc;
            padding: 12px;
            border-radius: 8px;
            border: 1px solid #e2e8f0;
        }
        .engine-card h3 {
            color: #1e293b;
            font-size: 14px;
            margin-bottom: 4px;
        }
        .engine-card p {
            color: #64748b;
            font-size: 12px;
            margin-bottom: 8px;
        }
        .engine-card .tags {
            margin-top: 8px;
        }
        .loading {
            display: inline-block;
            width: 16px;
            height: 16px;
            border: 2px solid #ffffff;
            border-radius: 50%;
            border-top-color: transparent;
            animation: spin 0.6s linear infinite;
            margin-left: 8px;
        }
        @keyframes spin {
            to { transform: rotate(360deg); }
        }
        .tab-buttons {
            display: flex;
            gap: 8px;
            margin-bottom: 16px;
            border-bottom: 1px solid #e5e7eb;
            padding-bottom: 8px;
        }
        .tab-btn {
            padding: 8px 16px;
            background: transparent;
            border: none;
            border-radius: 6px;
            cursor: pointer;
            font-size: 14px;
            color: #6b7280;
            transition: all 0.2s;
        }
        .tab-btn.active {
            background: #e0e7ff;
            color: #4338ca;
            font-weight: 500;
        }
        .tab-btn:hover {
            background: #f1f5f9;
        }
        .tab-content {
            display: none;
        }
        .tab-content.active {
            display: block;
        }
        .copy-btn {
            position: absolute;
            top: 8px;
            right: 8px;
            padding: 4px 12px;
            background: rgba(255,255,255,0.1);
            border: none;
            border-radius: 4px;
            color: #94a3b8;
            cursor: pointer;
            font-size: 12px;
        }
        .copy-btn:hover {
            background: rgba(255,255,255,0.2);
            color: #e2e8f0;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📄 DocReader API 测试界面</h1>
            <p>gRPC 服务地址: <strong>{{ grpc_address }}</strong>
            <span class="status {{ status_class }}">{{ status_text }}</span></p>
        </div>

        <div class="card">
            <h2>📚 解析引擎列表</h2>
            <button class="btn btn-secondary" onclick="loadEngines()">刷新引擎列表</button>
            <div id="engines-list" class="engine-grid">
                <p style="color: #999;">点击"刷新引擎列表"获取可用引擎...</p>
            </div>
        </div>

        <div class="card">
            <h2>🔧 文档解析测试</h2>
            <div class="tab-buttons">
                <button class="tab-btn active" onclick="switchTab('file')">文件上传</button>
                <button class="tab-btn" onclick="switchTab('url')">URL 解析</button>
            </div>

            <div id="tab-file" class="tab-content active">
                <div class="form-group">
                    <label>选择文件</label>
                    <div class="file-input" id="drop-zone" onclick="document.getElementById('file-input').click()">
                        <input type="file" id="file-input" accept=".pdf,.doc,.docx,.md,.txt,.xlsx,.xls,.ppt,.pptx,.csv">
                        <p>点击或拖拽文件到此处</p>
                        <p id="file-name" style="color: #667eea; margin-top: 8px;"></p>
                    </div>
                </div>
            </div>

            <div id="tab-url" class="tab-content">
                <div class="form-group">
                    <label>文档 URL</label>
                    <input type="text" id="url-input" placeholder="https://example.com/document">
                </div>
                <div class="form-group">
                    <label>标题 (可选)</label>
                    <input type="text" id="title-input" placeholder="文档标题">
                </div>
            </div>

            <div class="form-group">
                <label>解析引擎</label>
                <select id="engine-select">
                    <option value="">默认 (自动选择)</option>
                    <option value="builtin">builtin (内置引擎)</option>
                    <option value="markitdown">markitdown (MarkItDown)</option>
                </select>
            </div>

            <div class="form-group">
                <label>请求 ID (可选)</label>
                <input type="text" id="request-id" placeholder="test-{{ timestamp }}">
            </div>

            <button class="btn" id="submit-btn" onclick="submitRequest()">开始解析</button>
        </div>

        <div class="card" id="response-card" style="display: none;">
            <h2>📊 响应结果</h2>
            <button class="copy-btn" onclick="copyResponse()">复制</button>
            <div id="response-content" class="response"></div>
        </div>
    </div>

    <script>
        const GRPC_ADDRESS = '{{ grpc_address }}';
        let selectedFile = null;

        // 文件拖拽处理
        const dropZone = document.getElementById('drop-zone');
        const fileInput = document.getElementById('file-input');

        dropZone.addEventListener('dragover', (e) => {
            e.preventDefault();
            dropZone.classList.add('dragover');
        });

        dropZone.addEventListener('dragleave', () => {
            dropZone.classList.remove('dragover');
        });

        dropZone.addEventListener('drop', (e) => {
            e.preventDefault();
            dropZone.classList.remove('dragover');
            if (e.dataTransfer.files.length > 0) {
                handleFile(e.dataTransfer.files[0]);
            }
        });

        fileInput.addEventListener('change', (e) => {
            if (e.target.files.length > 0) {
                handleFile(e.target.files[0]);
            }
        });

        function handleFile(file) {
            selectedFile = file;
            document.getElementById('file-name').textContent = `已选择: ${file.name} (${formatFileSize(file.size)})`;
        }

        function formatFileSize(bytes) {
            if (bytes === 0) return '0 Bytes';
            const k = 1024;
            const sizes = ['Bytes', 'KB', 'MB', 'GB'];
            const i = Math.floor(Math.log(bytes) / Math.log(k));
            return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
        }

        function switchTab(tab) {
            document.querySelectorAll('.tab-btn').forEach(btn => btn.classList.remove('active'));
            document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));

            if (tab === 'file') {
                document.querySelector('.tab-btn:nth-child(1)').classList.add('active');
                document.getElementById('tab-file').classList.add('active');
            } else {
                document.querySelector('.tab-btn:nth-child(2)').classList.add('active');
                document.getElementById('tab-url').classList.add('active');
            }
        }

        function loadEngines() {
            const btn = event.target;
            btn.innerHTML = '加载中<span class="loading"></span>';

            fetch('/api/engines')
                .then(res => res.json())
                .then(data => {
                    const container = document.getElementById('engines-list');
                    container.innerHTML = data.engines.map(eng => `
                        <div class="engine-card">
                            <h3>${eng.name}</h3>
                            <p>${eng.description}</p>
                            <p style="color: ${eng.available ? '#10b981' : '#ef4444'}">
                                ${eng.available ? '✓ 可用' : '✗ ' + (eng.unavailable_reason || '不可用')}
                            </p>
                            <div class="tags">
                                ${eng.file_types.slice(0, 6).map(ft => `<span class="tag">${ft}</span>`).join('')}
                                ${eng.file_types.length > 6 ? `<span class="tag">+${eng.file_types.length - 6}</span>` : ''}
                            </div>
                        </div>
                    `).join('');
                    btn.textContent = '刷新引擎列表';
                })
                .catch(err => {
                    alert('加载引擎列表失败: ' + err);
                    btn.textContent = '刷新引擎列表';
                });
        }

        function submitRequest() {
            const tab = document.querySelector('.tab-content.active').id;
            const requestData = {
                parser_engine: document.getElementById('engine-select').value || '',
                request_id: document.getElementById('request-id').value || `test-${Date.now()}`
            };

            const btn = document.getElementById('submit-btn');
            btn.innerHTML = '处理中<span class="loading"></span>';
            btn.disabled = true;

            if (tab === 'tab-file') {
                if (!selectedFile) {
                    alert('请先选择文件');
                    btn.innerHTML = '开始解析';
                    btn.disabled = false;
                    return;
                }

                const reader = new FileReader();
                reader.onload = (e) => {
                    requestData.file_content = Array.from(new Uint8Array(e.target.result));
                    requestData.file_name = selectedFile.name;
                    requestData.file_type = getFileType(selectedFile.name);
                    sendRequest('/api/read', requestData);
                };
                reader.readAsArrayBuffer(selectedFile);
            } else {
                requestData.url = document.getElementById('url-input').value;
                requestData.title = document.getElementById('title-input').value;
                if (!requestData.url) {
                    alert('请输入文档 URL');
                    btn.innerHTML = '开始解析';
                    btn.disabled = false;
                    return;
                }
                sendRequest('/api/read', requestData);
            }
        }

        function getFileType(filename) {
            const ext = filename.split('.').pop().toLowerCase();
            const types = {
                'pdf': 'pdf', 'doc': 'doc', 'docx': 'docx',
                'md': 'md', 'markdown': 'md', 'txt': 'md',
                'xlsx': 'xlsx', 'xls': 'xls', 'csv': 'csv',
                'ppt': 'ppt', 'pptx': 'pptx'
            };
            return types[ext] || 'md';
        }

        function sendRequest(url, data) {
            fetch(url, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(data)
            })
            .then(res => res.json())
            .then(result => {
                displayResponse(result);
                const btn = document.getElementById('submit-btn');
                btn.innerHTML = '开始解析';
                btn.disabled = false;
            })
            .catch(err => {
                displayResponse({ error: '请求失败: ' + err });
                const btn = document.getElementById('submit-btn');
                btn.innerHTML = '开始解析';
                btn.disabled = false;
            });
        }

        function displayResponse(result) {
            const card = document.getElementById('response-card');
            const content = document.getElementById('response-content');
            card.style.display = 'block';

            if (result.error) {
                content.className = 'response error';
                content.textContent = '错误: ' + result.error;
            } else {
                content.className = 'response success';
                const summary = {
                    markdown_length: result.markdown_content?.length || 0,
                    images_count: result.image_refs?.length || 0,
                    images: result.image_refs || [],
                    metadata: result.metadata || {}
                };

                // 先显示头部信息
                let headerHtml = `
<div style="color: #10b981;">✓ 解析成功</div>
<div style="margin-top: 12px;">
<div><strong>内容长度:</strong> ${summary.markdown_length} 字符</div>
<div><strong>图片数量:</strong> ${summary.images_count}</div>
${summary.images.length > 0 ? `<div><strong>图片:</strong></div>${summary.images.map(img => `  - ${img.filename} (${img.mime_type})`).join('<br>')}` : ''}
</div>
<hr style="border-color: #334155; margin: 12px 0;">
<div style="color: #64748b; margin-bottom: 8px;">Markdown 内容 (流式输出):</div>
`;
                content.innerHTML = headerHtml + '<pre id="streaming-content" style="color: #e2e8f0; white-space: pre-wrap;"></pre>';

                // 流式输出内容
                streamMarkdown(result.markdown_content || '');
            }
        }

        // 流式输出 Markdown 内容
        function streamMarkdown(text) {
            const target = document.getElementById('streaming-content');
            if (!target) return;

            const chunkSize = 100; // 每次显示的字符数
            let index = 0;

            function displayNextChunk() {
                if (index >= text.length) {
                    return;
                }

                const end = Math.min(index + chunkSize, text.length);
                const chunk = text.substring(index, end);
                target.textContent += escapeHtml(chunk);
                index = end;

                // 滚动到底部
                target.scrollTop = target.scrollHeight;

                // 继续下一块
                requestAnimationFrame(displayNextChunk);
            }

            displayNextChunk();
        }

        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }

        function copyResponse() {
            const content = document.getElementById('response-content').textContent;
            navigator.clipboard.writeText(content).then(() => {
                alert('已复制到剪贴板');
            });
        }

        // 页面加载时自动检查状态
        loadEngines();
    </script>
</body>
</html>
"""


@app.route('/')
def index():
    """主页 - 显示测试界面"""
    return render_template_string(
        HTML_TEMPLATE,
        grpc_address=GRPC_ADDRESS,
        status_class='connected',
        status_text='已连接'
    )


@app.route('/api/engines')
def list_engines():
    """获取可用解析引擎列表"""
    try:
        with grpc.insecure_channel(GRPC_ADDRESS) as channel:
            client = docreader_pb2_grpc.DocReaderStub(channel)
            response = client.ListEngines(docreader_pb2.ListEnginesRequest(), timeout=5)
            engines = [
                {
                    'name': e.name,
                    'description': e.description,
                    'file_types': list(e.file_types),
                    'available': e.available,
                    'unavailable_reason': e.unavailable_reason
                }
                for e in response.engines
            ]
            return jsonify({'engines': engines})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/read', methods=['POST'])
def read_document():
    """解析文档"""
    try:
        data = request.get_json()

        # 构建 ReadRequest
        req = docreader_pb2.ReadRequest(
            config=docreader_pb2.ReadConfig(
                parser_engine=data.get('parser_engine', ''),
                parser_engine_overrides={}
            ),
            request_id=data.get('request_id', '')
        )

        # 处理文件或URL
        if 'file_content' in data:
            req.file_content = bytes(data['file_content'])
            req.file_name = data.get('file_name', 'file')
            req.file_type = data.get('file_type', 'md')
        elif 'url' in data:
            req.url = data['url']
            req.title = data.get('title', '')

        # 调用 gRPC 服务
        with grpc.insecure_channel(GRPC_ADDRESS) as channel:
            client = docreader_pb2_grpc.DocReaderStub(channel)
            response = client.Read(req, timeout=30)

            # 返回结果
            result = {
                'markdown_content': response.markdown_content,
                'image_refs': [
                    {
                        'filename': ref.filename,
                        'original_ref': ref.original_ref,
                        'mime_type': ref.mime_type,
                        'storage_key': ref.storage_key
                    }
                    for ref in response.image_refs
                ],
                'image_dir_path': response.image_dir_path,
                'metadata': dict(response.metadata),
                'error': response.error if response.error else None
            }

            if response.error:
                return jsonify({'error': response.error}), 400

            return jsonify(result)

    except grpc.RpcError as e:
        return jsonify({'error': f'gRPC Error: {e.code()} - {e.details()}'}), 500
    except Exception as e:
        return jsonify({'error': str(e)}), 500


if __name__ == '__main__':
    port = int(os.environ.get('WEB_TEST_PORT', '8000'))
    print(f'\n========================================')
    print(f'📄 DocReader Web 测试界面')
    print(f'========================================')
    print(f'🌐 测试界面: http://localhost:{port}')
    print(f'🔌 gRPC 服务: {GRPC_ADDRESS}')
    print(f'========================================\n')
    app.run(host='0.0.0.0', port=port, debug=True)
