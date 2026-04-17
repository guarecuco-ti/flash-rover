// Copyright (c) 2020, Texas Instruments.
// Licensed under the BSD-3-Clause license
// (see LICENSE or <https://opensource.org/licenses/BSD-3-Clause>) All files in the project
// notice may not be copied, modified, or distributed except according to those terms.

use std::path::{Path, PathBuf};
use std::process::Command;

use snafu::{Backtrace, ResultExt, Snafu};

#[derive(Debug, Snafu)]
pub enum Error {
    #[snafu(display("xdsdfu not found at {}: ensure CCS is properly installed", path.display()))]
    XdsDfuNotFound { path: PathBuf },
    #[snafu(display("Failed to run xdsdfu: {}", source))]
    XdsDfuFailed {
        source: std::io::Error,
        backtrace: Backtrace,
    },
}

pub type Result<T, E = Error> = std::result::Result<T, E>;

pub fn run(ccs_path: &Path) -> Result<()> {
    let exe = if cfg!(windows) { "xdsdfu.exe" } else { "xdsdfu" };
    let xdsdfu = ccs_path
        .join("ccs_base/common/uscif/xds110")
        .join(exe);

    ensure!(xdsdfu.exists(), XdsDfuNotFound { path: xdsdfu.clone() });

    Command::new(&xdsdfu)
        .arg("-e")
        .status()
        .context(XdsDfuFailed {})?;

    Ok(())
}
