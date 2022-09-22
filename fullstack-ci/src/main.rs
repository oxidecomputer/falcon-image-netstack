use std::env;

use libfalcon::{
    cli::{run, RunMode},
    error::Error,
    unit::gb,
    Node, NodeRef, Runner,
};

#[tokio::main]
async fn main() -> Result<(), Error> {
    let mut d = Runner::new("ci");
    let image = &env::var("IMAGE").expect("set image to a valid image name");
    let interface = &env::var("INTERFACE")
        .expect("set interface for nodes to bind to for external connectivity");

    //
    // Nodes
    //

    // sleds
    let sled1 = d.node("sled1", image, 2, gb(2));
    let sled2 = d.node("sled2", image, 2, gb(2));

    // sidecar/scrimlet nodes
    let scrimlet1 = d.node("scrimlet1", image, 4, gb(16));
    let scrimlet2 = d.node("scrimlet2", image, 4, gb(16));

    // External gateway
    let gateway = d.node("gateway", image, 2, gb(2));

    let topology = [sled1, sled2, scrimlet1, scrimlet2, gateway];

    //
    // Inter-node links
    //

    d.softnpu_link(
        scrimlet1,
        sled1,
        Some("a8:e1:de:00:00:01".into()),
        Some("a8:e1:de:01:70:1a".into()),
    );

    d.softnpu_link(
        scrimlet1,
        sled2,
        Some("a8:e1:de:00:00:02".into()),
        Some("a8:e1:de:01:70:1b".into()),
    );

    d.softnpu_link(
        scrimlet2,
        sled1,
        Some("a8:e1:de:00:01:01".into()),
        Some("a8:e1:de:01:70:1c".into()),
    );

    d.softnpu_link(
        scrimlet2,
        sled2,
        Some("a8:e1:de:00:01:02".into()),
        Some("a8:e1:de:01:70:1d".into()),
    );

    d.softnpu_link(
        scrimlet1,
        gateway,
        Some("a8:e1:de:00:02:01".into()),
        Some("a8:e1:de:01:70:1e".into()),
    );

    d.softnpu_link(
        scrimlet2,
        gateway,
        Some("a8:e1:de:00:02:02".into()),
        Some("a8:e1:de:01:70:1f".into()),
    );


    //
    // External links
    //

    for node in topology {
        d.ext_link(interface, node);
    }

    //
    // Mounts
    //

    for node in topology {
        d.mount("./cargo-bay", "/opt/cargo-bay", node)?;
    }

    if let RunMode::Launch = run(&mut d).await? {
        for (idx, node) in topology.iter().enumerate() {
            let number = idx + 1;
            let name = &d.get_node(*node).name;

            if name.contains("scrimlet") {
                init_scrimlet(&d, node, number).await?;
            } else {
                init_node(&d, node, number).await?;
            }
        }

        let sled1_path1_test = d
            .exec(sled1, "ping -N fe80::aae1:deff:fe01:701a fd00:2::1")
            .await?;
        if !sled1_path1_test.contains("fd00:2::1 is alive") {
            return Err(Error::Exec(sled1_path1_test));
        }

        let sled1_path2_test = d
            .exec(sled1, "ping -N fe80::aae1:deff:fe01:701c fd00:2::1")
            .await?;
        if !sled1_path2_test.contains("fd00:2::1 is alive") {
            return Err(Error::Exec(sled1_path2_test));
        }

        let sled2_path1_test = d
            .exec(sled2, "ping -N fe80::aae1:deff:fe01:701b fd00:1::1")
            .await?;
        if !sled2_path1_test.contains("fd00:1::1 is alive") {
            return Err(Error::Exec(sled2_path1_test));
        }

        let sled2_path2_test = d
            .exec(sled2, "ping -N fe80::aae1:deff:fe01:701d fd00:1::1")
            .await?;
        if !sled2_path2_test.contains("fd00:1::1 is alive") {
            return Err(Error::Exec(sled2_path2_test));
        }
    }

    Ok(())
}

fn display(node: &Node, text: &str) {
    println!("\n{}:\n\n{}\n", node.name, text);
}

async fn exec_commands(
    runner: &Runner,
    node_ref: &NodeRef,
    commands: &[&str],
) -> Result<(), Error> {
    for command in commands {
        let stdout = runner.exec(*node_ref, command).await?;
        display(runner.get_node(*node_ref), &stdout)
    }
    Ok(())
}

///
/// Configuration needed for normal sleds
///
async fn init_node(runner: &Runner, node_ref: &NodeRef, number: usize) -> Result<(), Error> {
    display(runner.get_node(*node_ref), "initializing node...");
    let commands = &[
        "chmod +x /opt/cargo-bay/init-node.sh",
        &format!("NODE_NUM={} /opt/cargo-bay/init-node.sh", number),
    ];
    exec_commands(runner, node_ref, commands).await?;
    Ok(())
}

///
///  Configuration needed for scrimlets
///
async fn init_scrimlet(runner: &Runner, node_ref: &NodeRef, number: usize) -> Result<(), Error> {
    let node = runner.get_node(*node_ref);
    display(node, "initializing node...");
    let commands: &[&str] = &[
        &format!("chmod +x /opt/cargo-bay/init-{}.sh", node.name),
        &format!("NODE_NUM={} /opt/cargo-bay/init-{}.sh", number, node.name),
    ];
    exec_commands(runner, node_ref, commands).await?;
    Ok(())
}
