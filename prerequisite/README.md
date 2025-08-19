## Manual Steps

1. Create an IAM user and access key for the IAM user.
2. Set up on GitHub
   - https://github.com/gonBorn/profile-board/settings/secrets/actions
   - Add the following secrets:
     - `AWS_ACCESS_KEY_ID`: The access key ID of the IAM user.
     - `AWS_SECRET_ACCESS_KEY`: The secret access key of the IAM user.
     - `DB_PASSWORD`
     - `IAM_USER_ARN`
3. Create EC2 key Pairs (name: profile-board-key) and download the pem file.
