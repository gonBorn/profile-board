## Manual Steps

1. Create an IAM user with inline policy, refer to [aws-iam.yml](aws-iam.yml) for details.
2. Create an access key for the IAM user.
3. Set up on GitHub
   - https://github.com/gonBorn/profile-board/settings/secrets/actions
   - Add the following secrets:
     - `AWS_ACCESS_KEY_ID`: The access key ID of the IAM user.
     - `AWS_SECRET_ACCESS_KEY`: The secret access key of the IAM user.
     - `DB_PASSWORD`
4. Create EC2 key Pairs (name: profile-board-key) and download the pem file.
