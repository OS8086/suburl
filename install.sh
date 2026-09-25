sudo apt install -y subfinder pipx git build-essential

git clone https://github.com/blechschmidt/massdns.git /tmp/massdns
cd /tmp/massdns
make
sudo make install
cd -

go install github.com/gwen001/github-subdomains@latest 
go install github.com/projectdiscovery/httpx/cmd/httpx@latest
go install github.com/projectdiscovery/tlsx/cmd/tlsx@latest
go install github.com/d3mondev/puredns/v2@latest 
go install github.com/bp0lr/gauplus@latest
go install github.com/tomnomnom/waybackurls@latest
pipx install git+https://github.com/xnl-h4ck3r/waymore.git
go install github.com/projectdiscovery/katana/cmd/katana@latest

go install github.com/tomnomnom/unfurl@latest
go install -v github.com/tomnomnom/anew@latest
pipx install uro
go install github.com/tomnomnom/gf@latest
mkdir -p ~/.gf
git clone https://github.com/1ndianl33t/Gf-Patterns.git /tmp/Gf-Patterns
cp /tmp/Gf-Patterns/*.json ~/.gf/
