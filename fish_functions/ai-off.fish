=== ai-off.fish ===
function ai-off --description 'Stoppar både llama-server och rag-mcp på BC-250 för helt neutralt idle-läge'
    ssh -t johnb@100.x.y.z "sudo systemctl stop llama-server.service rag-mcp.service && echo 'BC-250: Både LLM och RAG-modell avlastade (neutralt idle-läge).'"
end
