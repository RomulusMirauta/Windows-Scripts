gh repo list <GitHub user OR organization name> --limit 100 | ForEach-Object { gh repo clone $_.split()[0] }
