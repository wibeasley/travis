% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/travis-auth.R
\name{browse_travis_token}
\alias{browse_travis_token}
\title{Authenticate to Travis}
\usage{
browse_travis_token(endpoint = get_endpoint())
}
\arguments{
\item{endpoint}{\verb{[string]}\cr
Which Travis endpoint to use. Defaults to ".org". Accepted values are \code{".com"}
and \code{".org"}. Can be set globally via env var \code{R_TRAVIS}.}
}
\description{
A Travis API Key is needed to interact with the Travis API.
\code{browse_travis_token()} opens a browser window for the respective Travis
endpoint. On this site, you can copy your personal API key and then follow
the instructions of the console output or the ones shown below.
}
\section{Store API Key}{


The \code{travis} package supports two ways of storing the Travis API key(s):
\itemize{
\item via env vars \code{R_TRAVIS_ORG} and \code{R_TRAVIS_COM}
\item via \verb{~/.travis/config.yml}
}

The latter should already be present if you already used the \code{travis} CLI
tool at some point in the past. If not, its up to your preference which
approach to use.

The following instructions should help to set up \verb{~/.travis/config.yml}
correctly:
\enumerate{
\item Copy the token from the browser window which just opened. You can use
\code{edit_travis_config()} to open \verb{~/.travis/config.yml}.
\item The token should be stored using the following structure\preformatted{endpoints:
 https://api.travis-ci.<endpoint>/:
   access_token: <token>
}

with \verb{<endpoint>} being either 'com' or 'org'.
}
}

