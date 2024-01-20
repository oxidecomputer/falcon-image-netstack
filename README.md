# falcon-image-netstack
Netstack image builder for falcon

**Archive Notice**
This repository is being archived and will eventually be deleted. The netstack is now built into the helios image and this repository is no longer needed.

## Usage
### Triggering a CI build

Update `version.txt` with the new version, commit and tag, then push.
CI will pull the latest artifacts and publish a new image.

### Local build

Run the script directly from the project root.

```bash
.github/buildomat/jobs/netstack-image.sh
```

## TODO

- [ ] update `falcon-bits.sh` to use same strategy as `netstack-bits` for
      pulling latest packages

