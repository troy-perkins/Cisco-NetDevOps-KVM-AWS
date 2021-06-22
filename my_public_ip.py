from requests import get

response = get('https://api.ipify.org?format=json')
print(response.text)
