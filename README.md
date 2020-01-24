# README

RaiseTech講義用のサンプルアプリケーション
- 前提
 - Ruby 2.7.0
 - Rails 6.0.2.1
 - Nginx 1.17.8
 - MySQL 5.7.27
- 開発環境
 - Rails(localhost:3000)
 - MySQL(local)
- 本番環境
 - Rails on Nginx
 - MySQL(Amazon RDS for MySQL)

# Setup
EC2インスタンス上に環境構築を行う手順を記載する。
※t2.microではメモリ不足なのでt2.small以上が必須
```sh
# yumのパッケージをアップデート
sudo yum update -y
# git, dockerのインストール
sudo yum install -y git docker
# dockerの起動      
sudo service docker start           
# ec2-userをdockerグループに入れる。これでec2-userがdockerコマンドを実行できる
sudo usermod -aG docker ec2-user
# dockerの起動確認
sudo docker info

# docker-compose(1.25.0)のインストール
sudo curl -L "https://github.com/docker/compose/releases/download/1.25.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# ソースコードを取得
git clone https://github.com/Hirokazu-Okazaki/RaiseTechMySQLApp.git
```

# Usage
- 開発環境

```sh
# リポジトリに移動
cd RaiseTechMySQLApp

# コンテナをビルド
docker-compose -f docker-compose.development.yml build --no-cache

# ERROR: Couldn't connect to Docker daemon at http+docker://localhost - is it running?
# が表示された場合、EC2インスタンスに再接続してください

# credentialsの再作成
docker-compose -f docker-compose.development.yml run app rm config/credentials.yml.enc
docker-compose -f docker-compose.development.yml run -e EDITOR="vi" app bundle exec rails credentials:edit

# credentialsファイルのユーザーを変更
sudo chown -R $USER:$USER .

# コンテナを起動
docker-compose -f docker-compose.development.yml up -d

# MySQL(Local)のテーブルを作成
docker-compose -f docker-compose.development.yml run app bundle exec rails db:create
docker-compose -f docker-compose.development.yml run app bundle exec rails db:migrate

# SSHでEC2に接続している場合、ポート番号3000, 3306をLocalForwardしてください
# http://localhost:3000/users でアクセスできます

# コンテナを停止
docker-compose -f docker-compose.development.yml down
```

- 本番環境

```sh
# リポジトリに移動
cd RaiseTechMySQLApp

# 環境変数ファイルの整備
mv .env.sample .env

# DBの接続先を変更してください
vi .env

# APP_DATABASE_HOST=host
# APP_DATABASE=database
# APP_DATABASE_USER=user
# APP_DATABASE_PASSWORD=password
# ↓
# APP_DATABASE_HOST=sample.ap-northeast-1.rds.amazonaws.com
# APP_DATABASE=your_database_name
# APP_DATABASE_USER=your_database_user
# APP_DATABASE_PASSWORD=your_database_password

# ドメイン名を変更してください
vi containers/nginx/app.conf

# ドメインもしくはIPを指定
# server_name www.raisetechokazaki.tk;
# ↓
# server_name www.your_domain;

# コンテナをビルド
docker-compose -f docker-compose.production.yml build --no-cache

# credentialsの再作成
docker-compose -f docker-compose.production.yml run app rm config/credentials.yml.enc
docker-compose -f docker-compose.production.yml run -e EDITOR="vi" app bundle exec rails credentials:edit

# precompile
docker-compose -f docker-compose.production.yml run app bundle exec rails assets:precompile

# credentialsファイルのユーザーを変更
sudo chown -R $USER:$USER .

# コンテナを起動
docker-compose -f docker-compose.production.yml up -d

# ERROR: Couldn't connect to Docker daemon at http+docker://localhost - is it running?
# が表示された場合、EC2インスタンスに再接続してください

# MySQL(RDS)のテーブルを作成
docker-compose -f docker-compose.production.yml run app bundle exec rails db:create
docker-compose -f docker-compose.production.yml run app bundle exec rails db:migrate

# https://www.your_domainでアクセスできます

# コンテナを停止
docker-compose -f docker-compose.production.yml down
```

