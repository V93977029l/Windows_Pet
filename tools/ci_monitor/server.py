#!/usr/bin/env python3
"""CI Monitor MCP Server — 监控 GitHub Actions CI，失败时自动检索向量知识库。

工具：
  check_ci_status      — 查询最新 CI 运行状态
  wait_for_ci          — 阻塞等待 CI 完成（失败时自动查向量库）
  get_ci_failure_details — 获取失败 Job 详情
  query_similar_errors — 搜索向量知识库
  store_ci_error       — 存入向量知识库
"""

import asyncio
import io
import json
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT_DIR / "tools" / "vector_db"))

from mcp.server import Server  # noqa: E402
from mcp.server.stdio import stdio_server  # noqa: E402
from mcp.types import Tool, TextContent  # noqa: E402

GITHUB_REPO = "V93977029l/Windows_Pet"
GITHUB_API = f"https://api.github.com/repos/{GITHUB_REPO}"
HEADERS = {"Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"}


async def gh(endpoint: str) -> dict | list:
    import urllib.request, urllib.error
    req = urllib.request.Request(f"{GITHUB_API}/{endpoint}", headers=HEADERS)
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        return {"error": f"HTTP {e.code}", "msg": str(e)[:300]}


def vdb_query(text: str, n: int = 3) -> list:
    from query import query as vq
    old = sys.stdout
    sys.stdout = io.StringIO()
    try:
        vq(text, limit=n, json_output=True)
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
        Tool(name="check_ci_status", description="查询 GitHub Actions 最新 CI 运行状态",
             inputSchema={"type": "object", "properties": {
                 "branch": {"type": "string", "default": "main"},
                 "limit": {"type": "integer", "default": 3}}}),
        Tool(name="wait_for_ci", description="阻塞等待 CI 完成。失败时自动查向量库。",
             inputSchema={"type": "object", "properties": {
                 "branch": {"type": "string", "default": "main"},
                 "poll_interval": {"type": "integer", "default": 30},
                 "max_wait": {"type": "integer", "default": 1200}}}),
        Tool(name="get_ci_failure_details", description="获取 CI 失败 Job 信息",
             inputSchema={"type": "object", "properties": {
                 "run_id": {"type": "string"}}, "required": ["run_id"]}),
        Tool(name="query_similar_errors", description="搜索向量知识库",
             inputSchema={"type": "object", "properties": {
                 "query": {"type": "string"}, "limit": {"type": "integer", "default": 3}},
                 "required": ["query"]}),
        Tool(name="store_ci_error", description="存入向量知识库",
             inputSchema={"type": "object", "properties": {
                 "symptom": {"type": "string"}, "root_cause": {"type": "string"},
                 "fix": {"type": "string"}, "error_type": {"type": "string", "default": "ci"},
                 "module": {"type": "string", "default": "github-actions"}},
                 "required": ["symptom", "root_cause", "fix"]}),
    ]


@server.call_tool()
async def call_tool(name: str, args: dict) -> list[TextContent]:
    if name == "check_ci_status":
        d = await gh(f"actions/runs?branch={args.get('branch', 'main')}&per_page={args.get('limit', 3)}")
        if isinstance(d, dict) and "error" in d:
            return [TextContent(type="text", text=json.dumps(d, ensure_ascii=False))]
        runs = d.get("workflow_runs", [])
        if not runs:
            return [TextContent(type="text", text="无 CI 记录")]
        items = []
        for r in runs:
            icon = {"completed": "✅" if r.get("conclusion") == "success" else "❌",
                    "in_progress": "🔄", "queued": "⏳"}.get(r["status"], "❓")
            items.append(f"- {icon} [{r['id']}] {r['name']} `{r['status']}` / `{r.get('conclusion', '?')}`")
        return [TextContent(type="text", text="## CI 状态\n" + "\n".join(items))]

    elif name == "wait_for_ci":
        branch = args.get("branch", "main")
        d = await gh(f"actions/runs?branch={branch}&per_page=1")
        if not (runs := (d or {}).get("workflow_runs", [])):
            return [TextContent(type="text", text=f"{branch} 无 CI 运行")]
        rid = str(runs[0]["id"])
        t0 = time.time()
        while time.time() - t0 < args.get("max_wait", 1200):
            d = await gh(f"actions/runs/{rid}")
            if d.get("status") == "completed":
                c = d.get("conclusion", "?")
                out = [f"## CI [{rid}] 完成\n- **{c}**\n- {d.get('html_url', '')}"]
                if c == "failure":
                    jobs = await gh(f"actions/runs/{rid}/jobs")
                    failed = [j["name"] for j in (jobs.get("jobs", []) if isinstance(jobs, dict) else []) if j.get("conclusion") == "failure"]
                    if failed:
                        out.append("\n### 失败: " + ", ".join(failed))
                    sim = vdb_query(f"CI 失败 {d.get('name', '')}", 2)
                    if sim:
                        out.append("\n### 向量库:")
                        for s in sim:
                            out.append(f"- ({s['similarity']}%) {s['metadata']['fix'][:100]}")
                return [TextContent(type="text", text="\n".join(out))]
            await asyncio.sleep(args.get("poll_interval", 30))
        return [TextContent(type="text", text=f"⏰ 超时")]

    elif name == "get_ci_failure_details":
        r = await gh(f"actions/runs/{args['run_id']}")
        j = await gh(f"actions/runs/{args['run_id']}/jobs")
        out = [f"## Run {args['run_id']}", f"- {r.get('conclusion', '?')}", r.get('html_url', '')]
        for job in (j.get("jobs", []) if isinstance(j, dict) else []):
            out.append(f"- {'❌' if job['conclusion'] == 'failure' else '✅'} {job['name']}")
        return [TextContent(type="text", text="\n".join(out))]

    elif name == "query_similar_errors":
        r = vdb_query(args["query"], args.get("limit", 3))
        if not r:
            return [TextContent(type="text", text="未找到")]
        return [TextContent(type="text", text="\n".join(
            [f"## \"{args['query']}\""] + [
                f"### {i+1}. ({x['similarity']}%)\n- {x['metadata']['symptom']}\n- 修复: {x['metadata']['fix']}"
                for i, x in enumerate(r)
            ]))]

    elif name == "store_ci_error":
        subprocess.run([sys.executable, str(ROOT_DIR / "tools/vector_db/store.py"),
                        "--symptom", args["symptom"], "--root-cause", args["root_cause"],
                        "--fix", args["fix"], "--type", args.get("error_type", "ci"),
                        "--module", args.get("module", "github-actions"), "--source", "ci"],
                       capture_output=True, timeout=30, cwd=str(ROOT_DIR))
        return [TextContent(type="text", text="已存储")]

    return [TextContent(type="text", text=f"未知: {name}")]


async def main():
    async with stdio_server() as (read_stream, write_stream):
        await server.run(read_stream, write_stream, server.create_initialization_options())


if __name__ == "__main__":
    asyncio.run(main())