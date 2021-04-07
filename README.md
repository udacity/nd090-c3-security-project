# Deploying The Juice Store Infrastructure

- Clone the repository in to your local machine
- Run the `deploy.ps1` powershell script in the root directory and authenticate either with user login or existing SPN (see below)

## Authenticate with User Login

```
./deploy.ps1 -tenantID &lt;Azure-Tenant-ID&gt; -subscriptionID &lt;Azure-Subscription-ID&gt; -domainName &lt;Azure-AD-Domain-Name&gt; -usermode
```

## Authenticate with existing SPN

```
./deploy.ps1 -tenantID &lt;Azure-Tenant-ID&gt; -subscriptionID &lt;Azure-Subscription-ID&gt; -domainName &lt;Azure-AD-Domain-Name&gt;
```

### Resources

- Azure-AD-Domain-Name: [Find your Azure Active Directory Domain](https://azurecostmonitor.uservoice.com/knowledgebase/articles/805068-find-your-azure-active-directory-domain)

- Azure-Tenant-ID: [Find your Azure Active Directory tenant ID](https://docs.microsoft.com/en-us/azure/active-directory/fundamentals/active-directory-how-to-find-tenant)

- Azure-Subscription-ID: [Locate Your Unique Subscription ID](https://docs.bitnami.com/azure/faq/administration/find-subscription-id/)
