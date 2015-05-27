# Parallel::ForkManager Examples

The programs in the examples directory show the use of the Parallel::ForkManager
gem.

To run them from this directory use a command like:

    ruby -Ilib examples/data_structures_advanced.rb

The programs are discussed below.

## callbacks.rb

Example of a program using callbacks to get child exit codes.

## data_structures_string.rb

In this simple example, each child sends back a string.

## data_structures_advanced.rb

A second data structure retrieval example demonstrates how children
decide whether or not to send anything back, what to send and how the
parent should process whatever is retrieved.

## parallel_http_get.rb

Use multiple workers to fetch data from URLs.

## use_pfm.rb
