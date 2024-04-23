# Nocturne

A pure-Ruby client library for MySQL-compatible database servers, inspired by
https://github.com/trilogy-libraries/trilogy

## TODO

- Multi-statement and multi-result
- caching_sha2_password auth
- Capabilities exchange
- SSL options
- Charset option and more encodings
- #connected_host, #connection_options, #query_with_flags, #set_server_option, #server_info, #in_transaction, #gtid
- Lots of error handling

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add nocturne

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install nocturne

## Usage

```
connection = Nocturne.new
result = connection.query("SELECT 1")
result.rows
connection.close
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`rake test` to run the tests. You can also run `bin/console` for an interactive
prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To
release a new version, update the version number in `version.rb`, and then run
`bundle exec rake release`, which will create a git tag for the version, push
git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/composerinteralia/nocturne. This project is intended to be a
safe, welcoming space for collaboration, and contributors are expected to adhere
to the [code of conduct](https://github.com/composerinteralia/nocturne/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Nocturne project's codebases, issue trackers, chat
rooms and mailing lists is expected to follow the [code of conduct](https://github.com/composerinteralia/nocturne/blob/main/CODE_OF_CONDUCT.md).
