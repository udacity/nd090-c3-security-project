Please execute **deploy.ps1** once the subscription is ready. command to run
## Authenticating with existing SPN
  > ./deploy.ps1 -tenantID &lt;Azure-Tenant-ID&gt; -subscriptionID &lt;Azure-Subscription-ID&gt; -domainName &lt;Azure-AD-Domain-Name&gt;

## Authenticating with User Login (For students who want to use their own Azure Account)
  > ./deploy.ps1 -tenantID &lt;Azure-Tenant-ID&gt; -subscriptionID &lt;Azure-Subscription-ID&gt; -domainName &lt;Azure-AD-Domain-Name&gt; -usermode

Please follow this  [link](https://azurecostmonitor.uservoice.com/knowledgebase/articles/805068-find-your-azure-active-directory-domain) to get the Azure-AD-Domain-Name  

Please follow this [link](https://docs.microsoft.com/en-us/azure/active-directory/fundamentals/active-directory-how-to-find-tenant) to get Azure-Tenant-ID

Please follow this [link](https://docs.bitnami.com/azure/faq/administration/find-subscription-id/)
to get Azure-Subscription-ID