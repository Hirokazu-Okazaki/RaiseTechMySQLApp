ARG RUBY_VERSION

FROM ruby:$RUBY_VERSION

ARG APP_PATH
ENV APP_PATH=$APP_PATH
ENV LANG ja_JP.UTF-8

# 依存関係をインストール
RUN curl -sL https://deb.nodesource.com/setup_10.x | bash -
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
RUN apt-get update && apt-get install -y \
    build-essential \
    nodejs \
    yarn \
    default-mysql-client \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# ディレクトリの作成と移動
WORKDIR $APP_PATH

# ホストのGemfileなどをコンテナへコピー
COPY Gemfile Gemfile.lock ./

# Bundlerを更新
RUN gem update bundler
# BundlerでGemをインストール
RUN bundle install
# カレントディレクトリの内容をコンテナへコピー
COPY . .
# yarnをインストール
RUN yarn install --check-files

# Add a script to be executed every time the container starts.
COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]
EXPOSE 3000

# コンテナ起動時にRailsサーバを起動
CMD ["rails", "server", "-b", "0.0.0.0"]