use harper_core::core_version;
use harper_core::Document;
use harper_core::linting::{Lint, Linter, LintGroup};
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::ptr;

/// Returns the version of the harper-core library as a C string.
/// The caller is responsible for freeing the returned string using `harper_free_string`.
#[no_mangle]
pub extern "C" fn harper_version() -> *mut c_char {
    CString::new(core_version())
        .expect("Failed to create CString")
        .into_raw()
}

/// Frees a string that was allocated by Rust and passed to C.
/// # Safety
/// This function is unsafe because it can cause undefined behaviour if the pointer is invalid.
#[no_mangle]
pub unsafe extern "C" fn harper_free_string(s: *mut c_char) {
    if !s.is_null() {
        let _ = CString::from_raw(s);
    }
}

/// Creates a new document from plain English text.
/// Returns a pointer to the document, or null if there was an error.
/// The caller is responsible for freeing the document using harper_free_document.
#[no_mangle]
pub extern "C" fn harper_create_document(text: *const c_char) -> *mut Document {
    if text.is_null() {
        return ptr::null_mut();
    }

    let text_str = match unsafe { CStr::from_ptr(text) }.to_str() {
        Ok(s) => s,
        Err(_) => return ptr::null_mut(),
    };
    
    let doc = Document::new_plain_english_curated(text_str);
    Box::into_raw(Box::new(doc))
}

/// Frees a document created by harper_create_document.
#[no_mangle]
pub extern "C" fn harper_free_document(doc: *mut Document) {
    if !doc.is_null() {
        unsafe {
            let _ = Box::from_raw(doc);
        }
    }
}

/// Gets the full text content of the document.
/// Returns a newly allocated C string that must be freed by the caller using free().
/// Returns NULL if the document is NULL or if memory allocation fails.
#[no_mangle]
pub extern "C" fn harper_get_document_text(doc: *const Document) -> *mut c_char {
    if doc.is_null() {
        return ptr::null_mut();
    }

    let doc = unsafe { &*doc };
    let text = doc.get_full_string();
    
    match CString::new(text) {
        Ok(cstr) => cstr.into_raw(),
        Err(_) => ptr::null_mut(),
    }
}

#[no_mangle]
pub extern "C" fn harper_get_token_count(doc: *const Document) -> i32 {
    if doc.is_null() {
        return 0;
    }

    let doc = unsafe { &*doc };
    doc.get_tokens().len() as i32
}

#[no_mangle]
pub extern "C" fn harper_create_lint_group() -> *mut LintGroup {
    let dictionary = harper_core::spell::FstDictionary::curated();
    let lint_group = harper_core::linting::LintGroup::new_curated(
        std::sync::Arc::new(dictionary),
        harper_core::Dialect::Australian,
    );
    Box::into_raw(Box::new(lint_group))
}

#[no_mangle]
pub extern "C" fn harper_free_lint_group(lint_group: *mut LintGroup) {
    if !lint_group.is_null() {
        unsafe {
            let _ = Box::from_raw(lint_group);
        }
    }
}

#[no_mangle]
pub extern "C" fn harper_get_lints(
    doc: *const Document,
    lint_group: *mut LintGroup,
    count: *mut i32,
) -> *mut *mut Lint {
    if doc.is_null() || lint_group.is_null() || count.is_null() {
        return std::ptr::null_mut();
    }
    let doc = unsafe { &*doc };
    let lint_group = unsafe { &mut *lint_group };

    let lints = lint_group.lint(doc);

    let boxed_lints: Vec<Box<Lint>> = lints.into_iter().map(Box::new).collect();
    let mut raw_lints: Vec<*mut Lint> = boxed_lints.into_iter().map(Box::into_raw).collect();

    unsafe {
        *count = raw_lints.len() as i32;
    }

    let result = raw_lints.as_mut_ptr();
    std::mem::forget(raw_lints);
    result
}

#[no_mangle]
pub extern "C" fn harper_free_lints(lints: *mut *mut Lint, count: i32) {
    if lints.is_null() || count <= 0 {
        return;
    }

    unsafe {
        let lints_vec = Vec::from_raw_parts(lints, count as usize, count as usize);

        for lint in lints_vec {
            if !lint.is_null() {
                let _ = Box::from_raw(lint);
            }
        }
    }
}

#[no_mangle]
pub extern "C" fn harper_free_lint(lint: *mut Lint) {
    if !lint.is_null() {
        unsafe { let _ = Box::from_raw(lint); }
    }
}

#[no_mangle]
pub extern "C" fn harper_get_lint_message(lint: *const Lint) -> *mut c_char {
    if lint.is_null() {
        return std::ptr::null_mut();
    }
    let lint = unsafe { &*lint };
    let message = lint.message.to_string();
    match CString::new(message) {
        Ok(cstr) => cstr.into_raw(),
        Err(_) => std::ptr::null_mut(),
    }
}

#[no_mangle]
pub extern "C" fn harper_get_lint_start_and_end(lint: *const Lint, start: *mut i64, end: *mut i64) -> bool {
    if lint.is_null() {
        return false;
    }
    let lint = unsafe { &*lint };
    unsafe {
        *start = lint.span.start as i64;
        *end = lint.span.end as i64;
    }
    true
}

#[no_mangle]
pub extern "C" fn harper_get_lint_suggestion_count(lint: *const Lint) -> i32 {
    if lint.is_null() {
        return 0;
    }
    let lint = unsafe { &*lint };
    lint.suggestions.len() as i32
}

#[no_mangle]
pub extern "C" fn harper_get_lint_suggestion_text(lint: *const Lint, index: i32) -> *mut c_char {
    if lint.is_null() || index < 0 {
        return std::ptr::null_mut();
    }
    let lint = unsafe { &*lint };
    let idx = index as usize;
    if idx >= lint.suggestions.len() {
        return std::ptr::null_mut();
    }
    let sugg = &lint.suggestions[idx];
    match CString::new(sugg.to_string()) {
        Ok(cstr) => cstr.into_raw(),
        Err(_) => std::ptr::null_mut(),
    }
}