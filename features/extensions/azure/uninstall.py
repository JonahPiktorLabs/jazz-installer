import click

from utils.api_config import update_config
from utils.jenkins import setCredential, startJob


featureName = "Azure"


@click.command()
@click.option('--jazz-stackprefix',
              envvar='JAZZ_STACKPREFIX',
              help='Stackprefix of your Jazz installation (e.g. myjazz), your existing config will be imported',
              prompt=True)
@click.option('--scm-repo', envvar='SCM_REPO', help='Specify the scm repo url', prompt=True)
@click.option('--scm-username', envvar='SCM_USERNAME', help='Specify the scm username', prompt=True)
@click.option('--scm-password', envvar='SCM_PASSWORD', help='Specify the scm password', prompt=True)
@click.option('--scm-pathext', envvar='SCM_PATHEXT', help='Specify the scm repo path ext (Use "scm" for bitbucket)',
              default='')
@click.option('--azure-subscription-id', envvar='AZURE_SUBSCRIPTION_ID',
              help='Specify the ID for the azure subscription to deploy functions into',
              prompt=True)
@click.option('--azure-location', envvar='AZURE_LOCATION', help='Specify the location to install functions',
              prompt=True)
@click.option('--azure-client-id', envvar='AZURE_CLIENT_ID',
              help='Specify the client id for the Service Principal used to build infrastructure',
              prompt=True)
@click.option('--azure-client-secret', envvar='AZURE_CLIENT_SECRET', help='Specify the password for Service Principal',
              prompt=True)
@click.option('--azure-tenant-id', envvar='AZURE_TENANT_ID',
              help='Specify the Azure AD tenant id for the Service Principal', prompt=True)
@click.option('--azure-company-name', envvar='AZURE_COMPANY_NAME',
              help='Specify the company name used in the Azure API Management service',
              prompt=True)
@click.option('--azure-company-email', envvar='AZURE_COMPANY_EMAIL',
              help='Specify the company contact email used in the Azure API Management service', prompt=True)
def uninstall(jazz_stackprefix, scm_repo, scm_username, scm_password, scm_pathext, azure_subscription_id,
              azure_location, azure_client_id, azure_client_secret, azure_tenant_id, azure_company_name,
              azure_company_email):
    click.secho('\n\nThis will remove {0} functionality from your Jazz deployment'.format(featureName), fg='blue')
