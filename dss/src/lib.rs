// Copyright (c) 2020 , Texas Instruments.
// Licensed under the BSD-3-Clause license
// (see LICENSE or <https://opensource.org/licenses/BSD-3-Clause>) All files in the project
// notice may not be copied, modified, or distributed except according to those terms.

extern crate jni;
extern crate path_clean;
extern crate path_slash;

pub mod com;

use std::fmt;
use std::path::Path;

use jni::{objects::JObject, JNIEnv, JNIVersion};
use path_clean::PathClean;

use com::ti::ccstudio::scripting::environment::ScriptingEnvironment;

pub mod sys;

#[derive(Debug)]
pub enum Error {
    Jni(jni::errors::Error),
    JavaException(String),
}

impl fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Error::Jni(e) => write!(f, "{}", e),
            Error::JavaException(msg) => write!(f, "{}", msg),
        }
    }
}

impl std::error::Error for Error {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            Error::Jni(e) => Some(e),
            Error::JavaException(_) => None,
        }
    }
}

impl From<jni::errors::Error> for Error {
    fn from(e: jni::errors::Error) -> Self {
        Error::Jni(e)
    }
}

/// Extract the Java exception message from a pending exception before converting to [`Error`].
///
/// JNI rule: only `ExceptionOccurred`, `ExceptionClear`, and a handful of other primitives are
/// safe while an exception is pending.  We clear the exception first, then call `getMessage()`.
pub fn extract_exception(env: &JNIEnv, err: jni::errors::Error) -> Error {
    if let jni::errors::Error::JavaException = err {
        if let Ok(throwable) = env.exception_occurred() {
            if !throwable.is_null() {
                // Must clear before making any further JNI calls.
                let _ = env.exception_clear();

                if let Ok(msg_val) = env.call_method(
                    JObject::from(throwable),
                    "getMessage",
                    "()Ljava/lang/String;",
                    &[],
                ) {
                    if let Ok(msg_jobj) = msg_val.l() {
                        if !msg_jobj.is_null() {
                            if let Ok(msg) = env.get_string(msg_jobj.into()) {
                                return Error::JavaException(String::from(msg));
                            }
                        }
                    }
                }
            }
        }

        // Exception could not be described — clear any residual state and return a placeholder.
        let _ = env.exception_clear();
        return Error::JavaException("Java exception was thrown".to_string());
    }

    Error::Jni(err)
}

pub type Result<T, E = Error> = std::result::Result<T, E>;

pub struct Dss {
    jvm: jni::JavaVM,
}

impl Dss {
    pub fn new(ccs_path: &Path) -> Result<Self> {
        let dss_classpath = ccs_path
            .join("ccs_base/DebugServer/packages/ti/dss/java/dss.jar")
            .clean();

        let jvm_args = jni::InitArgsBuilder::new()
            .version(JNIVersion::V8)
            .option(&format!("-Djava.class.path={}", dss_classpath.display()))
            .option("-Dfile.encoding=UTF8")
            .option("-Xms40m")
            .option("-Xmx384m")
            .build()
            .unwrap();

        let jvm = jni::JavaVM::new(jvm_args)?;
        jvm.attach_current_thread_permanently()?;

        Ok(Self { jvm })
    }

    pub fn scripting_environment(&self) -> Result<ScriptingEnvironment> {
        let env = self.jvm.get_env()?;
        Ok(ScriptingEnvironment::new(env)?)
    }
}
