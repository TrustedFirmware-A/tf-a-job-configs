def shellQuote(value) {
    "'${value.replace("'", "'\"'\"'")}'"
}
