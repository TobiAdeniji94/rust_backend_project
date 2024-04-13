use std::net::TcpListener;
use rust_project::run;

#[tokio::main]
async fn main() -> std::io::Result<()> {
    let address = TcpListener::bind("127.0.0.1:8080")?;
    run(address)?.await
}
