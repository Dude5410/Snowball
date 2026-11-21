=== ai-on.fish ===
function ai-on --description 'Startar rag-mcp och llama-server på BC-250 och väntar tills båda är redo'
    echo "Startar RAG och Gemma 4 på BC-250..."
    ssh -t johnb@100.95.138.9 "sudo systemctl start rag-mcp.service llama-server.service"
    while not curl -sf http://100.95.138.9:8081/health > /dev/null
        sleep 1
    end
    echo "BC-250: Både RAG och Gemma 4 är inladdade och redo i Cherry Studio"
end

