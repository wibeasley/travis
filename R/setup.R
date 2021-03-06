#' Setup deployment for Travis CI
#'
#' Creates a public-private key pair,
#' adds the public key to the GitHub repository via `github_add_key()`,
#' and stores the private key as an encrypted environment variable in Travis CI
#' via [travis_set_var()],
#' possibly in a different repository.
#' The \pkg{tic} companion package contains facilities for installing such a key
#' during a Travis CI build.
#'
#' @param path `[string]` \cr
#'   The path to the repository.
#' @param user `[string]` \cr
#'   Name of the Github user account.
#' @param repo `[string]`\cr
#'   The Travis CI repository to add the private key to, default: `repo`
#'   (the GitHub repo to which the public deploy key is added).
#' @param key_name_private `[string]`\cr
#'   The name of the private key of the SSH key pair which will be created.
#'   If not supplied, `"TRAVIS_DEPLOY_KEY_<endpoint>"` will be used.
#' @param key_name_public `[string]`\cr
#'   The name of the private key of the SSH key pair which will be created.
#'   If not supplied, `"Deploy key for Travis CI (<endpoint>)"` will be used.
#' @template endpoint
#' @template remote
#' @template quiet
#'
#' @export
use_travis_deploy <- function(path = usethis::proj_get(),
                              user = github_user()$login,
                              repo = github_info(
                                path = path,
                                remote = remote
                              )$name,
                              key_name_private = NULL,
                              key_name_public = NULL,
                              endpoint = get_endpoint(),
                              remote = "origin",
                              quiet = FALSE) {

  auth_github()
  check_endpoint()
  travis_check_api_key()

  # generate deploy key pair
  key <- openssl::rsa_keygen() # TOOD: num bits?

  # encrypt private key using tempkey and iv
  pub_key <- get_public_key(key)
  private_key <- encode_private_key(key)

  # set key names
  if (is.null(key_name_public)) {
    key_name_public <- sprintf(
      "Deploy key for Travis CI (%s)", endpoint
    )
  }

  if (is.null(key_name_private)) {
    key_name_private <- sprintf(
      "TRAVIS_DEPLOY_KEY_%s", toupper(sub("^[.]", "", endpoint))
    )
  }

  # Clear old keys on Github deploy key ----------------------------------------

  # query deploy key
  if (!quiet) {
    cli::cli_alert_info("Querying Github deploy keys from repo.")
  }
  gh_keys <- gh::gh("/repos/:owner/:repo/keys",
    owner = github_info(path = path, remote = remote)$owner$login, repo = repo
  )

  if (!gh_keys[1] == "") {
    gh_keys_names <- gh_keys %>%
      purrr::map_chr(~ .x$title)

    # delete old keys with no endpoint spec from prior {travis} versions
    # this helps to avoid having unused keys stored
    old_keys <- gh_keys_names %>%
      purrr::map_lgl(~ .x == "Deploy key for Travis CI" | .x == "travis+tic")
    if (any(old_keys == TRUE)) {
      purrr::walk(gh_keys[old_keys], ~
      gh::gh("DELETE /repos/:owner/:repo/keys/:key_id",
        owner = github_info(path = path, remote = remote)$owner$login,
        repo = repo,
        key_id = .x$id
      ))
      if (!quiet) {
        cli::cli_alert_info("Deleted unused old Travis deploy key(s) from
                             Github repo.", wrap = TRUE)
      }
    }
  }

  # check if key(s) exist ------------------------------------------------------

  # Github (public key)
  if (!gh_keys[1] == "") {
    public_key_exists <- any(gh_keys_names %in% key_name_public)
  } else {
    public_key_exists <- FALSE
  }

  # Travis (private key)
  private_key_exists <- travis_get_vars(
    repo = github_repo(path = path),
    endpoint = endpoint
  ) %>%
    purrr::map_lgl(~ .x$name == key_name_private) %>%
    any()

  if (private_key_exists && public_key_exists) {
    cli::cli_alert("Deploy keys for Travis CI ({.code {endpoint}})
                           already present. No action required.", wrap = TRUE)
    return(invisible("Deploy keys already present."))
  } else if (private_key_exists | public_key_exists ||
    !private_key_exists && !public_key_exists) {
    cli::cli_alert("At least one key part is missing (private or public).
                    Deleting old keys and adding new deploy keys for Travis CI
                    ({.code {endpoint}}) for repo {repo} to Travis CI and
                    Github", wrap = TRUE)
    cli::rule()
  } else if (!private_key_exists && !public_key_exists) {
    cli::cli_alert("Adding Deploy keys for Travis CI ({.code {endpoint}})
                    for repo {repo} to Travis CI and Github", wrap = TRUE)
    cli::rule()
  }

  # delete and set new keys since at least one is missing ----------------------

  if (public_key_exists) {
    cli::cli_alert("Clearing old public key on Github because its counterpart
                    (private key) is most likely missing on Travis CI.")
    # delete existing public key from github
    key_id <- which(gh_keys_names %>%
      purrr::map_lgl(~ .x == key_name_public))
    gh::gh("DELETE /repos/:owner/:repo/keys/:key_id",
      owner = github_info(path = path, remote = remote)$owner$login,
      repo = repo,
      key_id = gh_keys[[key_id]]$id
    )
  }

  # add to GitHub first, because this can fail because of missing org
  # permissions
  github_add_key(
    pubkey = pub_key, user = user, repo = repo,
    title = key_name_public
  )

  if (private_key_exists) {
    # delete existing private key from Travis
    travis_delete_var(travis_get_var_id(key_name_private,
      repo = github_repo(path = path), quiet = TRUE, endpoint = endpoint
    ),
    repo = github_repo(path = path), endpoint = endpoint
    )
  }

  travis_set_var(key_name_private, private_key,
    public = FALSE, repo = github_repo(path = path),
    endpoint = endpoint
  )

  cli::cat_rule()
  cli::cli_alert_success(
    "Added the private SSH key as a deploy key to project {.code {repo}} on
     Travis CI as secure environment variable {.var {key_name_private}}.",
    wrap = TRUE
  )
  cli::cli_alert_success(
    "Added the public SSH key as a deploy key to project {.code {repo}} on
     Github.",
    wrap = TRUE
  )
}

get_public_key <- function(key) {
  as.list(key)$pubkey
}

encode_private_key <- function(key) {
  conn <- textConnection(NULL, "w")
  openssl::write_pem(key, conn, password = NULL)
  private_key <- textConnectionValue(conn)
  close(conn)

  private_key <- paste(private_key, collapse = "\n")

  openssl::base64_encode(charToRaw(private_key))
}
