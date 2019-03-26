const TestToken = artifacts.require('TestToken');
const TestArbitration = artifacts.require('TestArbitration');
const TokenPayments = artifacts.require('TokenPayments');

class IdFactory {
  constructor() { this.counter = 0; }
  next() { return `0x${String(++this.counter).padStart(64, '0')}`; }
  last() { return `0x${String(this.counter).padStart(64, '0')}`; }
}

// From https://medium.com/coinmonks/testing-time-dependent-logic-in-ethereum-smart-contracts-1b24845c7f72
function send(method, params = []) {
  return new Promise((resolve, reject) => {
    const jsonrpc = '2.0';
    const id = 0;
    web3.currentProvider.send(
      { id, jsonrpc, method, params },
      (error, result) => error ? reject(error) : resolve(result)
    );
  });
}

async function fastForward(seconds) {
  await send('evm_increaseTime', [seconds]);
  await send('evm_mine');
}

async function blockNow() {
  const { result } = await send('eth_getBlockByNumber', ['latest', false]);
  return parseInt(result.timestamp);
}

contract('TokenPayments', accounts => {
  const owner = accounts[0];
  const guest = accounts[1];
  const host = accounts[2];
  const cancelPeriod = 15 * 60;
  const disputePeriod = 30 * 60;
  const price = '1000000000000000000';
  const deposit = '200000000000000000';
  const total = '1200000000000000000';
  const idFactory = new IdFactory();

  beforeEach(async () => {
    const payments = await TokenPayments.deployed();
    const token = await TestToken.deployed();
    const arbitration = await TestArbitration.deployed();
    const balance = await token.balanceOf(guest);
    await Promise.all([...accounts, arbitration.address].map(
      address => token.burnAll(address)
    ));
    await token.mint(total, guest);
    await token.approve(payments.address, '0', { from: guest });
  });

  it('prevents invoice without approval', async () => {
    const payments = await TokenPayments.deployed();
    const now = await blockNow();
    const id = idFactory.next();

    let thrown = undefined;
    try {
      await payments.invoice(
        id,
        host,
        guest,
        price,
        deposit,
        '0',
        now + cancelPeriod,
        now + disputePeriod,
        { from: host }
      );
    } catch (error) {
      thrown = error;
    }
    expect(thrown).not.to.equal(undefined);
  });

  it('prevents invoice with a short cancel period', async () => {
    const token = await TestToken.deployed();
    const payments = await TokenPayments.deployed();
    const now = await blockNow();
    const id = idFactory.next();
    await token.approve(payments.address, total, { from: guest });

    let thrown = undefined;
    try {
      await payments.invoice(
        id,
        host,
        guest,
        price,
        deposit,
        '0',
        now + 5,
        now + disputePeriod,
        { from: host }
      );
    } catch (error) {
      thrown = error;
    }
    expect(thrown).not.to.equal(undefined);
  });

  it('prevents invoice with a short dispute period', async () => {
    const token = await TestToken.deployed();
    const payments = await TokenPayments.deployed();
    const now = await blockNow();
    const id = idFactory.next();
    await token.approve(payments.address, total, { from: guest });

    let thrown = undefined;
    try {
      await payments.invoice(
        id,
        host,
        guest,
        price,
        deposit,
        '0',
        now + cancelPeriod,
        now + cancelPeriod + 5,
        { from: host }
      );
    } catch (error) {
      thrown = error;
    }
    expect(thrown).not.to.equal(undefined);
  });

  it('prevents invoice with excess cancellation fees', async () => {
    const token = await TestToken.deployed();
    const payments = await TokenPayments.deployed();
    const now = await blockNow();
    const id = idFactory.next();
    await token.approve(payments.address, total, { from: guest });

    let thrown = undefined;
    try {
      await payments.invoice(
        id,
        host,
        guest,
        price,
        deposit,
        '1200000000000000010',
        now + cancelPeriod,
        now + disputePeriod,
        { from: host }
      );
    } catch (error) {
      thrown = error;
    }
    expect(thrown).not.to.equal(undefined);
  });

  it('prevents invoice with null supplier', async () => {
    const token = await TestToken.deployed();
    const payments = await TokenPayments.deployed();
    const now = await blockNow();
    const id = idFactory.next();
    await token.approve(payments.address, total, { from: guest });

    let thrown = undefined;
    try {
      await payments.invoice(
        id,
        '0x0',
        guest,
        price,
        deposit,
        '0',
        now + cancelPeriod,
        now + disputePeriod,
        { from: host }
      );
    } catch (error) {
      thrown = error;
    }
    expect(thrown).not.to.equal(undefined);
  });

  it('prevents invoice with null purchaser', async () => {
    const token = await TestToken.deployed();
    const payments = await TokenPayments.deployed();
    const now = await blockNow();
    const id = idFactory.next();
    await token.approve(payments.address, total, { from: guest });

    let thrown = undefined;
    try {
      await payments.invoice(
        id,
        host,
        '0x0',
        price,
        deposit,
        '0',
        now + cancelPeriod,
        now + disputePeriod,
        { from: host }
      );
    } catch (error) {
      thrown = error;
    }
    expect(thrown).not.to.equal(undefined);
  });

  describe('on invoice with approved funds', () => {
    let result;

    beforeEach(async () => {
      const token = await TestToken.deployed();
      const payments = await TokenPayments.deployed();
      const now = await blockNow();
      const id = idFactory.next();

      await token.approve(payments.address, total, { from: guest });

      result = await payments.invoice(
        id,
        host,
        guest,
        price,
        deposit,
        "0",
        now + cancelPeriod,
        now + disputePeriod,
        { from: host }
      );
    });

    it('transfers funds to payments contract', async () => {
      const token = await TestToken.deployed();
      const payments = await TokenPayments.deployed();
      const balance = await token.balanceOf(payments.address);
      expect(balance.toString()).to.equal(total);
    });

    it('emits an Invoice event', async () => {
      expect(result.logs.length).to.equal(1);
      expect(result.logs[0].event).to.equal('Invoice');
    });
  });

  ['cancel', 'dispute', 'refund', 'payout'].forEach(method => {
    it(`prevents ${method} on unknown ids`, async () => {
      let thrown = undefined;
      try {
        await payments[method](idFactory.next());
      } catch (error) {
        thrown = error;
      }
      expect(thrown).not.to.equal(undefined);
    });
  });

  describe('after an invoice', () => {
    beforeEach(async () => {
      const token = await TestToken.deployed();
      const payments = await TokenPayments.deployed();
      const now = await blockNow();
      const id = idFactory.next();
      await token.approve(payments.address, total, { from: guest });
      result = await payments.invoice(
        id,
        host,
        guest,
        price,
        deposit,
        "0",
        now + cancelPeriod,
        now + disputePeriod,
        { from: host }
      );
    });

    it('does not allow host to cancel', async () => {
      const payments = await TokenPayments.deployed();
      const id = idFactory.last();
      let thrown = undefined;
      try {
        await payments.cancel(id, { from: host });
      } catch (error) {
        thrown = error;
      }
      expect(thrown).not.to.equal(undefined);
    });

    it('allows guest to cancel', async () => {
      const token = await TestToken.deployed();
      const payments = await TokenPayments.deployed();
      const id = idFactory.last();
      const oldBalance = await token.balanceOf(guest);
      expect(oldBalance.toString()).to.equal('0');
      await payments.cancel(id, { from: guest });
      const newBalance = await token.balanceOf(guest);
      expect(newBalance.toString()).to.equal(total);
    });

    it('does not allow host to payout', async () => {
      const payments = await TokenPayments.deployed();
      const id = idFactory.last();
      let thrown = undefined;
      try {
        await payments.payout(id, { from: host });
      } catch (error) {
        thrown = error;
      }
      expect(thrown).not.to.equal(undefined);
    });

    it('allows guests to initiate disputes', async () => {
      const payments = await TokenPayments.deployed();
      const arbitration = await TestArbitration.deployed();
      const token = await TestToken.deployed();
      const id = idFactory.last();
      await payments.dispute(id, { from: guest });
      const allowance = await token.allowance(
        payments.address,
        arbitration.address
      );
      expect(allowance.toString()).to.equal(total);
    });

    it('allows hosts to initiate disputes', async () => {
      const payments = await TokenPayments.deployed();
      const arbitration = await TestArbitration.deployed();
      const token = await TestToken.deployed();
      const id = idFactory.last();
      await payments.dispute(id, { from: host });
      const allowance = await token.allowance(
        payments.address,
        arbitration.address
      );
      expect(allowance.toString()).to.equal(total);
    });

    describe('after the cancel deadline', () => {
      beforeEach(() => fastForward(cancelPeriod + 1));

      it('does not allow guest to cancel', async () => {
        const payments = await TokenPayments.deployed();
        const id = idFactory.last();
        let thrown = undefined;
        try {
          await payments.cancel(id, { from: guest });
        } catch (error) {
          thrown = error;
        }
        expect(thrown).not.to.equal(undefined);
      });

      it('still does not allow host to payout', async () => {
        const payments = await TokenPayments.deployed();
        const id = idFactory.last();
        let thrown = undefined;
        try {
          await payments.payout(id, { from: host });
        } catch (error) {
          thrown = error;
        }
        expect(thrown).not.to.equal(undefined);
      });

      it('allows guests to initiate disputes', async () => {
        const payments = await TokenPayments.deployed();
        const arbitration = await TestArbitration.deployed();
        const token = await TestToken.deployed();
        const id = idFactory.last();
        await payments.dispute(id, { from: guest });
        const allowance = await token.allowance(
          payments.address,
          arbitration.address
        );
        expect(allowance.toString()).to.equal(total);
      });

      it('allows hosts to initiate disputes', async () => {
        const payments = await TokenPayments.deployed();
        const arbitration = await TestArbitration.deployed();
        const token = await TestToken.deployed();
        const id = idFactory.last();
        await payments.dispute(id, { from: host });
        const allowance = await token.allowance(
          payments.address,
          arbitration.address
        );
        expect(allowance.toString()).to.equal(total);
      });
      
      it('allows the contract owner to make a refund', async () => {
        const payments = await TokenPayments.deployed();
        const token = await TestToken.deployed();
        const id = idFactory.last();
        await payments.refund(id, { from: owner });
        const balance = await token.balanceOf(guest);
        expect(balance.toString()).to.equal(total);
      });

      it('allows the host to make a refund', async () => {
        const payments = await TokenPayments.deployed();
        const token = await TestToken.deployed();
        const id = idFactory.last();
        await payments.refund(id, { from: host });
        const balance = await token.balanceOf(guest);
        expect(balance.toString()).to.equal(total);
      });

      it('does not allow guest to make a refund', async () => {
        const payments = await TokenPayments.deployed();
        const token = await TestToken.deployed();
        const id = idFactory.last();
        let thrown = undefined;
        try {
          await payments.refund(id, { from: guest });
        } catch (error) {
          thrown = error;
        }
        expect(thrown).not.to.equal(undefined);
      });

      describe('after the dispute deadline', () => {
        beforeEach(() => fastForward(disputePeriod + 1));

        it('does not allow guests to initiate disputes', async () => {
          const payments = await TokenPayments.deployed();
          const arbitration = await TestArbitration.deployed();
          const token = await TestToken.deployed();
          const id = idFactory.last();
          let thrown = undefined;
          try {
            await payments.dispute(id, { from: guest });
          } catch (error) {
            thrown = error;
          }
          expect(thrown).not.to.equal(undefined);
        });

        it('does not allow hosts to initiate disputes', async () => {
          const payments = await TokenPayments.deployed();
          const arbitration = await TestArbitration.deployed();
          const token = await TestToken.deployed();
          const id = idFactory.last();
          let thrown = undefined;
          try {
            await payments.dispute(id, { from: host });
          } catch (error) {
            thrown = error;
          }
          expect(thrown).not.to.equal(undefined);
        });

        it('still does not allow guest to payout', async () => {
          const payments = await TokenPayments.deployed();
          const id = idFactory.last();
          let thrown = undefined;
          try {
            await payments.payout(id, { from: guest });
          } catch (error) {
            thrown = error;
          }
          expect(thrown).not.to.equal(undefined);
        });

        it('allows host to initiate payout', async () => {
          const payments = await TokenPayments.deployed();
          const token = await TestToken.deployed();
          const id = idFactory.last();
          await payments.payout(id, { from: host });
          const hostBalance = await token.balanceOf(host);
          const guestBalance = await token.balanceOf(guest);
          expect(hostBalance.toString()).to.equal(price);
          expect(guestBalance.toString()).to.equal(deposit);
        });

        ['host', 'guest', 'owner'].forEach(actor => {
          it(`does not allow ${actor} to cancel`, async () => {
            const payments = await TokenPayments.deployed();
            const token = await TestToken.deployed();
            const from = { host, guest, owner }[actor];
            const id = idFactory.last();
            let thrown = undefined;
            try {
              await payments.cancel(id, { from });
            } catch (error) {
              thrown = error;
            }
            expect(thrown).not.to.equal(undefined);
          });
        });
      });
    });
  });
});
