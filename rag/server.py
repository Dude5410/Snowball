import os
from pathlib import Path
import chromadb
from pypdf import PdfReader
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("BC250-RAG", host="100.x.y.z", port=PORT)
client = chromadb.PersistentClient(path="/home/johnb/rag-mcp/chroma_db")
collection = client.get_or_create_collection(name="docs")

@mcp.tool()
def index_docs() -> str:
    """Indexerar alla PDF-, TXT- och MD-filer i /home/johnb/rag-mcp/docs till ChromaDB."""
    docs_dir = Path("/home/johnb/rag-mcp/docs")
    added = 0
    for f in docs_dir.rglob("*"):
        if f.suffix.lower() not in {".pdf", ".txt", ".md"}:
            continue
        text = "\n".join(p.extract_text() or "" for p in PdfReader(f).pages) if f.suffix.lower() == ".pdf" else f.read_text(errors="ignore")
        chunks = [text[i:i+900] for i in range(0, len(text), 750) if text[i:i+900].strip()]
        if chunks:
            collection.upsert(
                ids=[f"{f.name}_{i}" for i in range(len(chunks))],
                documents=chunks,
                metadatas=[{"source": f.name, "chunk": i} for i in range(len(chunks))]
            )
            added += len(chunks)
    return f"Klart! Indexerade {added} chunks från {docs_dir}."

@mcp.tool()
def search_docs(query: str, n_results: int = 4) -> str:
    """Söker semantiskt i dokumentdatabasen på BC-250 och returnerar de mest relevanta textutdragen."""
    res = collection.query(query_texts=[query], n_results=n_results)
    if not res["documents"] or not res["documents"][0]:
        return "Inga matchande dokument hittades."
    return '\n\n---\n\n'.join(
        f"[{m['source']} #{m['chunk']}]\n{d}"
        for d, m in zip(res["documents"][0], res["metadatas"][0])
    )

if __name__ == "__main__":
    mcp.run(transport="sse")
