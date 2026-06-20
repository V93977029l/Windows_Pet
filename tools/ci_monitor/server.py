#!/usr/bin/env python3
"""CI Monitor MCP Server — 监控 GitHub Actions CI 状态，失败时自动检索向量知识库。

工具列表：
  check_ci_status     — 查询最新 CI 运行状态
  wait_for_ci          — 阻塞等待 CI 完成，返回结果（失败时自动查向量库）
  get_ci_failure_details — 获取 CI 失败详细日志
  query_similar_errors — 在向量知识库中搜索相似历史错误
  store_ci_error       — 将 CI 错误存入向量知识库

注册到 Trae MCP（.trae/mcp.json）：
{
  "mcpServers": {
    "ci-monitor": {
      "command": "python",
      "args": ["tools/ci_monitor/server.py"],
      "cwd": "f:/VSCode/game",
      "env": { "GITHUB_TOKEN": "" }
    }
  }
}
"""

import asyncio
import io
import json
import os
import subprocess
import sys
import time
from pathlib import Path

from mcp.server import Server  # noqa: E402
from mcp.server.stdio import stdio_server  # noqa: E402
from mcp.types import Tool, TextContent  # noqa: E402

ROOT_DIR = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT_DIR / "tools" / "vector_db"))

GITHUB_REPO = "V93977029l/Windows_Pet"
GITHUB_API = f"https://api.github.com/repos/{GITHUB_REPO}"
GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN", "")
HEADERS = {
    "Accept": "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
}
if GITHUB_TOKEN:
    HEADERS["Authorization"] = f"Bearer {GITHUB_TOKEN}"


async def github_request(endpoint: str) -> dict | list:
    import urllib.request
    import urllib.error

    req = urllib.request.Request(f"{GITHUB_API}/{endpoint}", headers=HEADERS)
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        return {
            "error": f"HTTP {e.code}",
            "message": (e.read().decode() if e.fp else str(e))[:500],
        }
    except Exception as e:
        return {"error": str(e)}


def vector_query(text: str, limit: int = 3) -> list:
    from query import query as vq

    old = sys.stdout
    sys.stdout = io.StringIO()
    try:
        vq(text, limit=limit, json_output=True)
        out = sys.stdout.getvalue().strip()
        return json.loads(out) if out else []
    except Exception:
        return []
    finally:
        sys.stdout = old


server = Server("ci-monitor")


@server.list_tools()
async def list_tools() -> list[Tool]:
    return [
        Tool(
            name="check_ci_status",
            description="查询 GitHub Actions 最新 CI 运行状态",
            inputSchema={
                "type": "object",
                "properties": {
                    "branch": {
                        "type": "string",
                        "description": "分支名，默认 main",
                        "default": "main",
                    },
                    "limit": {
                        "type": "integer",
                        "description": "返回近 N 次运行",
                        "default": 3,
                    },
                },
            },
        ),
        Tool(
            name="wait_for_ci",
            description="阻塞等待 CI 完成。失败时自动查询向量知识库中的相似错误。",
            inputSchema={
                "type": "object",
                "properties": {
                    "branch": {
                        "type": "string",
                        "description": "分支名",
                        "default": "main",
                    },
                    "poll_interval": {
                        "type": "integer",
                        "description": "轮询间隔（秒）",
                        "default": 30,
                    },
                    "max_wait": {
                        "type": "integer",
                        "description": "最大等待（秒）",
                        "default": 1200,
                    },
                },
            },
        ),
        Tool(
            name="get_ci_failure_details",
            description="获取 CI 失败运行的详细 job 信息",
            inputSchema={
                "type": "object",
                "properties": {
                    "run_id": {"type": "string", "description": "workflow run ID"}
                },
                "required": ["run_id"],
            },
        ),
        Tool(
            name="query_similar_errors",
            description="在向量知识库中搜索相似历史错误",
            inputSchema={
                "type": "object",
                "properties": {
                    "query": {"type": "string", "description": "错误描述"},
                    "limit": {
                        "type": "integer",
                        "description": "返回条数",
                        "default": 3,
                    },
                },
                "required": ["query"],
            },
        ),
        Tool(
            name="store_ci_error",
            description="将 CI 错误存入向量知识库",
            inputSchema={
                "type": "object",
                "properties": {
                    "symptom": {"type": "string", "description": "错误症状"},
                    "root_cause": {"type": "string", "description": "根因分析"},
                    "fix": {"type": "string", "description": "修复方案"},
                    "error_type": {"type": "string", "default": "ci"},
                    "module": {"type": "string", "default": "github-actions"},
                },
                "required": ["symptom", "root_cause", "fix"],
            },
        ),
    ]


@server.call_tool()
async def call_tool(name: str, arguments: dict) -> list[TextContent]:
    if name == "check_ci_status":
        data = await github_request(
            f"actions/runs?branch={arguments.get('branch', 'main')}&per_page={arguments.get('limit', 3)}"
        )
        if isinstance(data, dict) and "error" in data:
            return [
                TextContent(
                    type="text", text=json.dumps(data, ensure_ascii=False, indent=2)
                )
            ]
        runs = data.get("workflow_runs", [])
        if not runs:
            return [TextContent(type="text", text="没有 CI 运行记录")]
        icons = {
            "completed": lambda r: "✅" if r.get("conclusion") == "success" else "❌",
            "in_progress": lambda _: "🔄",
            "queued": lambda _: "⏳",
        }
        lines = ["## CI 状态\n"]
        for r in runs:
            icon = icons.get(r["status"], lambda _: "❓")(r)
            lines.append(
                f"- {icon} [{r['id']}] {r['name']} — `{r['status']}` / `{r.get('conclusion', '?')}`"
            )
        return [TextContent(type="text", text="\n".join(lines))]

    elif name == "wait_for_ci":
        branch = arguments.get("branch", "main")
        interval = arguments.get("poll_interval", 30)
        max_w = arguments.get("max_wait", 1200)
        data = await github_request(f"actions/runs?branch={branch}&per_page=1")
        if isinstance(data, dict) and "error" in data:
            return [TextContent(type="text", text=f"API 错误: {data}")]
        runs = data.get("workflow_runs", [])
        if not runs:
            return [TextContent(type="text", text=f"分支 {branch} 没有 CI 运行")]
        run_id = str(runs[0]["id"])
        start = time.time()
        while time.time() - start < max_w:
            data = await github_request(f"actions/runs/{run_id}")
            if isinstance(data, dict) and "error" in data:
                return [TextContent(type="text", text=f"查询失败: {data}")]
            if data.get("status") == "completed":
                conclusion = data.get("conclusion", "?")
                lines = [
                    f"## CI [{run_id}] 完成\n- 结论: **{conclusion}**",
                    f"- 分支: {data.get('head_branch', '?')}",
                    f"- URL: {data.get('html_url', '')}",
                ]
                if conclusion == "failure":
                    jobs_data = await github_request(f"actions/runs/{run_id}/jobs")
                    failed = (
                        [
                            j["name"]
                            for j in jobs_data.get("jobs", [])
                            if j.get("conclusion") == "failure"
                        ]
                        if not isinstance(jobs_data, dict) or "error" not in jobs_data
                        else []
                    )
                    if failed:
                        lines.append("\n### 失败 Job: " + ", ".join(failed))
                    similar = vector_query(
                        f"CI 失败 {data.get('name', '')} {conclusion}", 2
                    )
                    if similar:
                        lines.append("\n### 向量库相似错误:")
                        for s in similar:
                            lines.append(
                                f"- ({s['similarity']}%) {s['metadata']['symptom'][:80]}"
                            )
                            lines.append(f"  修复: {s['metadata']['fix'][:120]}")
                return [TextContent(type="text", text="\n".join(lines))]
            await asyncio.sleep(interval)
        return [TextContent(type="text", text=f"⏰ 等待超时 ({max_w}s)")]

    elif name == "get_ci_failure_details":
        rid = arguments["run_id"]
        run = await github_request(f"actions/runs/{rid}")
        jobs = await github_request(f"actions/runs/{rid}/jobs")
        lines = [
            f"## Run {rid}",
            f"- 结论: {run.get('conclusion', '?')}",
            f"- URL: {run.get('html_url', '')}",
        ]
        for j in jobs.get("jobs", []):
            icon = "✅" if j["conclusion"] == "success" else "❌"
            lines.append(f"- {icon} {j['name']}: `{j['conclusion']}`")
        return [TextContent(type="text", text="\n".join(lines))]

    elif name == "query_similar_errors":
        results = vector_query(arguments["query"], arguments.get("limit", 3))
        if not results:
            return [TextContent(type="text", text="未找到相似错误")]
        lines = [f'## 向量库搜索: "{arguments["query"]}"\n']
        for i, r in enumerate(results):
            m = r["metadata"]
            lines.append(f"### #{i + 1} 相似度 {r['similarity']}%")
            lines.append(f"- 症状: {m['symptom']}\n- 修复: {m['fix']}")
        return [TextContent(type="text", text="\n".join(lines))]

    elif name == "store_ci_error":
        cmd = [
            sys.executable,
            str(ROOT_DIR / "tools/vector_db/store.py"),
            "--symptom",
            arguments["symptom"],
            "--root-cause",
            arguments["root_cause"],
            "--fix",
            arguments["fix"],
            "--type",
            arguments.get("error_type", "ci"),
            "--module",
            arguments.get("module", "github-actions"),
            "--source",
            "ci",
        ]
        r = subprocess.run(
            cmd, capture_output=True, text=True, timeout=30, cwd=str(ROOT_DIR)
        )
        return [TextContent(type="text", text=r.stdout.strip() or r.stderr.strip())]

    return [TextContent(type="text", text=f"未知工具: {name}")]


async def main():
    async with stdio_server() as (read_stream, write_stream):
        await server.run(read_stream, write_stream, server.create_initialization_options())


if __name__ == "__main__":
    asyncio.run(main())
